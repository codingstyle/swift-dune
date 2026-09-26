#!/bin/zsh
# Run the iOS build in the simulator with dev-harness variables, wait, and copy
# the harness screenshots + log to build/shots/<run>/.
#
#   scripts/sim_run.sh <run-name> <seconds> [DUNE_START=game] [DUNE_SCRIPT=...]
#
# The simulator (an iPhone 14 Pro by default, SIM_DEVICE_TYPE to change it) is
# created on first use and its UDID kept in build/. It runs headless (no
# Simulator.app window) and is shut down afterwards.

set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
run="$1"; seconds="$2"; shift 2
bundle=$(awk '/PRODUCT_BUNDLE_IDENTIFIER:/ {print $2; exit}' "$repo_root/project-ios.yml")
device_type=${SIM_DEVICE_TYPE:-com.apple.CoreSimulator.SimDeviceType.iPhone-14-Pro}

cd "$repo_root"

# Prefer the iOS 16.4 runtime (the deployment target is iOS 16); fall back to
# the newest installed one. The UDID file records which runtime it was made for.
runtime=$(xcrun simctl list runtimes | awk '/iOS-16-4/ {print $NF}' | tail -1)
[[ -n $runtime ]] || runtime=$(xcrun simctl list runtimes | awk '/iOS/ {print $NF}' | tail -1)
udid_file=build/sim-udid-${runtime##*.}
if [[ ! -s $udid_file ]] || ! xcrun simctl list devices | grep -q "$(cat $udid_file)"; then
  mkdir -p build
  xcrun simctl create "Dune (${runtime##*SimRuntime.})" "$device_type" "$runtime" > $udid_file
fi
print "simulator runtime: $runtime"
sim=$(cat $udid_file)
xcrun simctl boot $sim 2>/dev/null || true

app=$(scripts/build_ios.sh sim | sed -n 's/^APP=//p')
xcrun simctl terminate $sim $bundle 2>/dev/null || true
xcrun simctl install $sim "$app"

data=$(xcrun simctl get_app_container $sim $bundle data)
rm -rf "$data/Documents/shots" "$data/Documents/dune-ios.log"

env_args=()
for kv in "$@"; do env_args+=("SIMCTL_CHILD_$kv"); done
env "${env_args[@]}" xcrun simctl launch $sim $bundle >/dev/null
sleep "$seconds"

out=build/shots/$run
rm -rf "$out"; mkdir -p "$out"
cp -R "$data/Documents/shots/." "$out/" 2>/dev/null || true
cp "$data/Documents/dune-ios.log" "$out/" 2>/dev/null || true
xcrun simctl io $sim screenshot "$out/device.png" >/dev/null 2>&1 || true
xcrun simctl shutdown $sim 2>/dev/null || true
print "OUT=$out"; ls "$out"
