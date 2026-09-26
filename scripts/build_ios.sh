#!/bin/zsh
# Build the iOS app and package an ad-hoc signed IPA for sideloading.
#
#   scripts/build_ios.sh            # device IPA -> builds/SwiftDune-ios-<stamp>.ipa
#   scripts/build_ios.sh sim        # simulator .app, printed as APP=...
#
# Derived data lives in build/ (gitignored); finished IPAs are kept in builds/.
# Signing: ad-hoc (codesign -s -).

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
stamp="$(date +%Y%m%d-%H%M%S)"
derived="$repo_root/build/derived"
mode="${1:-device}"

cd "$repo_root"
xcodegen generate --spec project-ios.yml --quiet

if [[ "$mode" == sim ]]; then
  xcodebuild -project SwiftDuneiOS.xcodeproj -target DuneiOS -configuration Debug \
    -sdk iphonesimulator ARCHS=arm64 ONLY_ACTIVE_ARCH=NO \
    SYMROOT="$derived/Build/Products" OBJROOT="$derived/Build/Intermediates" build -quiet
  print "APP=$derived/Build/Products/Debug-iphonesimulator/Dune.app"
  exit 0
fi

# No iOS simulator runtime is installed on this Mac and the "Any iOS Device"
# destination refuses to resolve, so build by -target/-sdk like the ScummVM
# iOS script does.
xcodebuild -project SwiftDuneiOS.xcodeproj -target DuneiOS -configuration Release \
  -sdk "${IOS_SDK:-iphoneos26.5}" ARCHS=arm64 ONLY_ACTIVE_ARCH=NO \
  SYMROOT="$derived/Build/Products" OBJROOT="$derived/Build/Intermediates" \
  CODE_SIGNING_ALLOWED=NO build -quiet

app="$derived/Build/Products/Release-iphoneos/Dune.app"
[[ -d "$app" ]] || { print -u2 "build did not produce $app"; exit 1; }

stage="$repo_root/build/ipa-$stamp"
mkdir -p "$stage/Payload" "$repo_root/builds"
cp -R "$app" "$stage/Payload/Dune.app"
codesign --force --deep --sign - --timestamp=none "$stage/Payload/Dune.app"
codesign --verify --deep --strict "$stage/Payload/Dune.app"

ipa="$repo_root/builds/SwiftDune-ios-$stamp.ipa"
ditto -c -k --sequesterRsrc --keepParent "$stage/Payload" "$ipa"
rm -rf "$stage"
print "IPA=$ipa"
