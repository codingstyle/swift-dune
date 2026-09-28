//
//  Battles.swift
//  SwiftDune
//
//  Troop marches and move orders, espionage, fort battles (MASSIVE ATTACK,
//  FIGHT FOR A WHOLE DAY), battles won and lost, forts becoming sietches,
//  military training, the Harkonnen captain, worm rides and the final
//  attack on the Harkonnen palace.
//
//  Port of the ScummVM Dune engine's troops.cpp and battle.cpp (and the
//  parts of world.cpp, story.cpp and scene.cpp that call them), read there
//  from the CD 3.7 executable (the seg000 addresses below) and specified in
//  that project's notes/speedrun/battle-worm-spec.md §1-§6
//  (github.com/AppTesterMC/desert-frost-engine). Troop and location bytes
//  are raw record offsets; ds variables are CD offsets (b/w/setB/setW).
//
//  Troop bytes: 1 next, 2 slot, 3 occupation, 4 location (while marching:
//  the destination), 6/8 position, 0x0A job start, 0x0C / 0x0E job counters
//  (espionage: troops seen / strength each; attacking: Harkonnens / Fremen
//  killed; training: countdown), 0x10 bits (0x80 Harkonnen, 0x40 report
//  done, 0x10 hidden, 0x20 converting a fort, 0x400 fought at a fort),
//  0x12 speech, 0x15 motivation, 0x17 army skill, 0x19 equipment (bit 7
//  harvester, 6 ornithopter, 5 krys knives, 4 laser guns, 3 weirding
//  modules, 2 atomics, 1 bulbs), 0x1A men / 10.
//

import Foundation


/// What Paul finds on arriving at a place (seg000:503c).
enum ArrivalOutcome {
    case safe
    /// The place is in battle: Paul joins it (ds:2B = 1); the first room
    /// offers MASSIVE ATTACK, FIGHT FOR A WHOLE DAY and CALL A WORM.
    case battle
    /// Harkonnens hold it and nobody fights them: Paul is shot
    /// (pendingEnding = 177).
    case shot
}


extension World {
    static let battleHere = 0x2B        // night_attack_stage: Paul is in a battle
    static let battleGaugeByte = 0xFD       // the "Battle:" gauge, odd while ds:2B is set
    static let sietchesAvailable = 0x27
    static let noRaid = 0x11BC          // bit 0: a job-6 tick suppresses the next Harkonnen raid
    static let prospectorTroop = 3      // the record at ds:08e0
    static let harkonnenPalaceIndex = 1 // location 1 (ds:011c)
    static let gurneyPlace = 0x101A     // raw: Gurney's record + 2, as ScummVM reads it

    // Troop record bytes.
    private static let tNext = 0x01, tSlot = 0x02, tOccupation = 0x03, tLocation = 0x04
    private static let tLongitude = 0x06, tLatitude = 0x08, tTime = 0x0A, tDepC = 0x0C, tDepE = 0x0E
    private static let tBits = 0x10, tSpeech = 0x12, tMotivation = 0x15, tArmy = 0x17
    private static let tEquipment = 0x19, tPopulation = 0x1A
    private static let moving: UInt8 = 0x40

    private static let statusBattle: UInt8 = 0x02
    private static let statusHeld: UInt8 = 0x08


    // MARK: Random numbers

    /// The executable seeds both generators from the BIOS tick count at
    /// startup (seg000:00c3), so they are not part of a save.
    func seedRandom() {
        let seed = UInt32(truncatingIfNeeded: Int64(Date().timeIntervalSince1970 * 1000))
        rngA = UInt16(truncatingIfNeeded: seed ^ 0x1234)
        rngB = UInt16(truncatingIfNeeded: (seed >> 16) ^ seed ^ 0x5A5A)
    }

    /// rand, seg000:e3cc: s = s * 0xCBD1 + 1; al = bits 8-15 of the new
    /// state, ah = bits 16-23 of the product.
    func lcgRand() -> UInt16 {
        let p = UInt32(rngA) * 0xCBD1 + 1
        rngA = UInt16(truncatingIfNeeded: p)
        return UInt16((p >> 8) & 0xFF) | UInt16((p >> 16) & 0xFF) << 8
    }

    /// rand_masked, seg000:e3b7: the same with 0xE56D on the second state.
    func lcgRandMasked(_ mask: UInt16) -> UInt16 {
        let p = UInt32(rngB) * 0xE56D + 1
        rngB = UInt16(truncatingIfNeeded: p)
        return (UInt16((p >> 8) & 0xFF) | UInt16((p >> 16) & 0xFF) << 8) & mask
    }


    // MARK: Chains and equipment

    static func placeOffset(_ index: Int) -> UInt16 {
        UInt16(Location.tableOffset + index * Location.recordSize)
    }

    private func isHarkonnen(_ id: Int) -> Bool { troopByte(id, World.tBits) & 0x80 != 0 }
    private func isLive(_ id: Int) -> Bool { troopByte(id, World.tOccupation) & 0x20 == 0 }

    /// seg000:858c: take the troop out of its place's chain.
    private func unlinkTroop(_ id: Int) {
        guard let index = troopPlace(id) else { return }
        let head = Int(locationByte(index, 9))
        if head == id {
            setLocationByte(index, 9, troopByte(id, World.tNext))
        } else {
            var previous = head, steps = 0
            while previous >= 1 && previous <= World.troopCount && steps < World.troopCount {
                steps += 1
                if Int(troopByte(previous, World.tNext)) == id {
                    setTroopByte(previous, World.tNext, troopByte(id, World.tNext))
                    break
                }
                previous = Int(troopByte(previous, World.tNext))
            }
        }
        setTroopByte(id, World.tNext, 0)
    }

    /// seg000:851f: Fremen take the first free slot from 1, Harkonnens from
    /// 9; the troop joins the end of the chain. Returns its slot.
    @discardableResult
    private func linkTroop(_ id: Int, _ index: Int) -> Int {
        let ids = troopsAt(index).map { $0.id }
        let harkonnen = isHarkonnen(id)
        var slot = harkonnen ? 9 : 1
        var clash = true
        while clash && slot < 31 {
            clash = false
            for other in ids where other != id && Int(troopByte(other, World.tSlot)) == slot {
                clash = true
                slot += 1
                break
            }
        }
        setTroopByte(id, World.tSlot, UInt8(slot))
        setTroopByte(id, World.tNext, 0)
        setTroopWord(id, World.tLocation, World.placeOffset(index))
        if let last = ids.last {
            setTroopByte(last, World.tNext, UInt8(id))
        } else {
            setLocationByte(index, 9, UInt8(id))
        }
        if !harkonnen && slot > 8 {
            // seg000:85cc: a Fremen troop past slot 8 evicts the first
            // captured Harkonnen troop there.
            for other in ids where isHarkonnen(other) && !isLive(other) {
                removeFromPlay(other)
                break
            }
        }
        return slot
    }

    /// seg000:7f5f (+) and 7f75 (-): a troop's items count in its place's
    /// row (bit 7 harvesters at +0x14 .. bit 1 bulbs at +0x1A).
    private func registerEquipment(_ id: Int, _ index: Int, _ sign: Int, mask: UInt8 = 0xFF) {
        let equipment = troopByte(id, World.tEquipment) & mask
        for k in 0..<7 where equipment & (0x80 >> k) != 0 {
            let count = locationByte(index, 0x14 + k)
            setLocationByte(index, 0x14 + k, sign > 0 ? (count < 255 ? count + 1 : 255) : (count > 0 ? count - 1 : 0))
        }
    }

    /// seg000:66b1: the troop leaves the game.
    private func removeFromPlay(_ id: Int) {
        unlinkTroop(id)
        setTroopWord(id, World.tLocation, 0)
        setTroopByte(id, World.tOccupation, 0xA0)
        setTroopByte(id, World.tPopulation, 0)
        setTroopByte(id, World.tEquipment, 0)
    }

    /// seg000:6ad4 / 6acb: the job (the whole byte, 6aea) with its clocks
    /// restarted; a job other than waiting shows its skill class (6b06).
    private func applyJob(_ id: Int, _ job: UInt8) {
        setTroopByte(id, World.tOccupation, job)
        if job != TroopJob.waitingForOrders {
            setTroopByte(id, World.tSpeech + 1,
                         troopByte(id, World.tSpeech + 1) | UInt8(truncatingIfNeeded: 0x20 << ((job & 0x0F) >> 2)))
        }
        setTroopWord(id, World.tTime, w(World.gameTime))
        setTroopWord(id, World.tDepC, 0)
        setTroopWord(id, World.tDepE, 0)
    }


    // MARK: Marches

    /// MOVE TROOP (troop_issue_move_order, seg000:84a6): the troop leaves
    /// its place and marches to `dest`, 7 steps at once, then 4 a period
    /// (8 with an ornithopter). A troop already marching is retargeted.
    /// Returns false when refused (a sietch or village under attack: the
    /// executable leaves the troop unlinked there, an original bug, spec
    /// §2.2). The UI calls it on the map's Done after picking the place.
    @discardableResult
    func issueMoveOrder(troop id: Int, to dest: Int) -> Bool {
        guard id >= 1 && id <= World.troopCount, dest >= 0 && dest < locationCount else { return false }
        let occupation = troopByte(id, World.tOccupation)
        if occupation & World.moving != 0 {
            setTroopWord(id, World.tLocation, World.placeOffset(dest))
            if occupation & 3 == 3 { setTroopByte(id, World.tOccupation, occupation & ~3) }
            return true
        }
        let from = troopPlace(id)
        let d = location(dest)
        if d.type < Location.fortressMin && d.status & World.statusBattle != 0 {
            DuneEngine.shared.logger.log(.info, "Troops: troop \(id) cannot march to place \(dest) under attack")
            return false
        }
        unlinkTroop(id)
        if let from = from {
            if occupation & 0x0F == TroopJob.attacking && location(from).status & World.statusBattle != 0
                && countHostiles(from).attacking == 0 {
                battleLost(from)
            }
            registerEquipment(id, from, -1)
            let f = location(from)
            setTroopWord(id, World.tLongitude, f.longitude)
            setTroopWord(id, World.tLatitude, UInt16(bitPattern: f.latitude))
        }
        if d.type < Location.fortressMin {
            // seg000:6f93: motivation - 3; below 5 the troop sulks.
            var m = troopByte(id, World.tMotivation)
            m = m >= 3 ? m - 3 : 0
            if m < 5 {
                m = 4
                setTroopByte(id, World.tOccupation, troopByte(id, World.tOccupation) | TroopJob.stopped)
                setTroopWord(id, World.tSpeech, troopWord(id, World.tSpeech) | 0x20)
            }
            setTroopByte(id, World.tMotivation, m)
        }
        setTroopWord(id, World.tLocation, World.placeOffset(dest))
        setTroopByte(id, World.tOccupation, troopByte(id, World.tOccupation) | World.moving)
        setTroopByte(id, World.tSlot, 0)
        DuneEngine.shared.logger.log(.info, "Troops: troop \(id) marches from place \(from.map { String($0) } ?? "-") to place \(dest)")
        if troopByte(id, World.tBits) & 0x10 == 0 { travelSubsteps(id, 7) }
        return true
    }

    /// Where a marching troop is now (map longitude, latitude), for its icon.
    func troopPosition(_ id: Int) -> (longitude: UInt16, latitude: Int) {
        (troopWord(id, World.tLongitude), Int(Int16(bitPattern: troopWord(id, World.tLatitude))))
    }

    func troopMarching(_ id: Int) -> Bool { troopByte(id, World.tOccupation) & World.moving != 0 }

    /// seg000:8604: one unit along the dominant gap; a gap under 7 cells is
    /// arrival (true).
    private func travelSubstep(_ id: Int) -> Bool {
        guard let dest = troopPlace(id) else { return true }
        let d = location(dest)
        var lng = troopWord(id, World.tLongitude)
        var lat = Int(Int16(bitPattern: troopWord(id, World.tLatitude)))
        let cells = max(1, rowCells(lat))
        let unit = max(1, 65536 / cells)
        let dLng = Int(Int16(bitPattern: d.longitude &- lng))
        let dLat = Int(d.latitude) - lat
        let gapLng = abs(dLng) / unit, gapLat = abs(dLat)
        if max(gapLng, gapLat) < 7 { return true }
        let minor = lcgRand() & 1 != 0
        let lngStep = UInt16(truncatingIfNeeded: dLng > 0 ? unit : -unit)
        if gapLng >= gapLat {
            lng = lng &+ lngStep
            if minor && dLat != 0 { lat += dLat > 0 ? 1 : -1 }
        } else {
            lat += dLat > 0 ? 1 : -1
            if minor && gapLng != 0 { lng = lng &+ lngStep }
        }
        setTroopWord(id, World.tLongitude, lng)
        setTroopWord(id, World.tLatitude, UInt16(truncatingIfNeeded: lat))
        return false
    }

    private func travelSubsteps(_ id: Int, _ n: Int) {
        for _ in 0..<n {
            if travelSubstep(id) {
                troopArrive(id)
                return
            }
        }
    }

    /// troop_travel_step (seg000:8308): 4 sub-steps a period, 8 with an
    /// ornithopter.
    func troopTravelStep(_ id: Int) {
        travelSubsteps(id, troopByte(id, World.tEquipment) & 0x40 != 0 ? 8 : 4)
    }

    /// troop_arrive_at_destination (seg000:8357).
    private func troopArrive(_ id: Int) {
        guard let index = troopPlace(id) else { return }
        let d = location(index)
        setTroopWord(id, World.tLongitude, d.longitude)
        setTroopWord(id, World.tLatitude, UInt16(bitPattern: d.latitude))
        setTroopByte(id, World.tOccupation, troopByte(id, World.tOccupation) & ~World.moving)
        linkTroop(id, index)
        registerEquipment(id, index, +1)
        let job = troopByte(id, World.tOccupation) & 0x0F
        if friendlyPlace(index) && d.status & World.statusBattle == 0 {
            applyJob(id, job == TroopJob.espionage || job == TroopJob.attacking ? TroopJob.militaryTraining : job)
            DuneEngine.shared.logger.log(.info, "Troops: troop \(id) arrives at place \(index)")
            return
        }
        applyJob(id, job)
        DuneEngine.shared.logger.log(.info, "Troops: troop \(id) arrives at hostile place \(index)")
        if job == TroopJob.espionage && d.hidden {
            // location_mark_discovered (seg000:425b); Tuono-Harg (first
            // name 3, last name 6) moves the story to 0x10.
            discover(index)
            if d.firstName == 3 && d.lastName == 6 { Story.shared.setGamePhase(0x10) }
            DuneEngine.shared.logger.log(.info, "Troops: espionage reveals place \(index)")
            return
        }
        if Int(locationByte(index, 9)) == id {
            battleWon(index)
            return
        }
        startAttack(at: index)
    }

    /// ATTACK (seg000:83fd): every hired troop at the place attacks (job 6);
    /// a prospector just stops. The UI calls it from the espionage troop's
    /// ATTACK row with the troop's place; arrivals call it too.
    func startAttack(at index: Int) {
        for t in troopsAt(index) {
            let id = t.id
            let occupation = troopByte(id, World.tOccupation)
            if occupation & 0x80 != 0 || isHarkonnen(id) || occupation & 0x60 != 0 { continue }
            if occupation & 0x0F == TroopJob.prospecting {
                setTroopByte(id, World.tOccupation, occupation | TroopJob.stopped)
            } else if occupation & 0x0F != TroopJob.attacking {
                applyJob(id, TroopJob.attacking)
            }
        }
        DuneEngine.shared.logger.log(.info, "Battle: the troops at place \(index) attack")
    }


    // MARK: Espionage

    /// seg000:5274's distance between two places: max(|dlng| >> 8, |dlat|).
    func placeDistance(_ a: Int, _ b: Int) -> Int {
        let p = location(a), q = location(b)
        return max(abs(Int(Int16(bitPattern: q.longitude &- p.longitude))) >> 8, abs(Int(q.latitude) - Int(p.latitude)))
    }

    /// The nearest hidden fortress or palace (the ds:E2/E4 part of
    /// seg000:5274), with its distance.
    func nearestHiddenHarkonnen(from: Int) -> (index: Int, distance: Int)? {
        var best: (index: Int, distance: Int)?
        for i in 0..<locationCount {
            let l = location(i)
            guard l.hidden && l.type >= Location.fortressMin else { continue }
            let d = placeDistance(from, i)
            if best == nil || d < best!.distance { best = (i, d) }
        }
        return best
    }

    /// ESPIONAGE is greyed unless a hidden fort lies within 30 cells of the
    /// troop's place (ds:E2 < 0x1E).
    func canStartEspionage(troop id: Int) -> Bool {
        guard let here = troopPlace(id), let target = nearestHiddenHarkonnen(from: here) else { return false }
        return target.distance < 0x1E
    }

    /// ESPIONAGE (seg000:6a45): the troop marches by itself to the nearest
    /// hidden fort within 30 cells; its arrival reveals the fort, then each
    /// period it counts and weighs the Harkonnens there (troop bytes
    /// 0x0C / 0x0E) and may be captured.
    @discardableResult
    func startEspionage(troop id: Int) -> Bool {
        guard let here = troopPlace(id), let target = nearestHiddenHarkonnen(from: here),
              target.distance < 0x1E else { return false }
        applyJob(id, TroopJob.espionage)
        setTroopByte(id, World.tBits, troopByte(id, World.tBits) & ~0x40)
        return issueMoveOrder(troop: id, to: target.index)
    }

    /// seg000:72b0: one period of a spy at a fort.
    func espionageTick(_ id: Int, _ index: Int) {
        let s = Int(troopByte(id, World.tArmy))
        let e = Int(w(World.gameTime) &- troopWord(id, World.tTime))
        let half = s < 80 ? (80 - s) / 2 : 0
        if troopByte(id, World.tBits) & 0x40 == 0 {
            if e > (half >> 1) && troopWord(id, World.tDepC) == 0 {
                // seg000:68d2: the hidden Harkonnen troops show.
                var seen = 0
                for t in troopsAt(index) where troopByte(t.id, World.tBits) & 0x10 != 0 {
                    setTroopByte(t.id, World.tBits, troopByte(t.id, World.tBits) & ~0x10)
                    seen += 1
                }
                setTroopWord(id, World.tDepC, UInt16(seen))
                if seen == 0 { setTroopByte(id, World.tBits, troopByte(id, World.tBits) | 0x40) }
            }
            if e > half && troopByte(id, World.tBits) & 0x40 == 0 {
                let forces = battleForces(at: index)
                let c = Int(troopWord(id, World.tDepC))
                setTroopWord(id, World.tDepE, UInt16(truncatingIfNeeded: c != 0 ? forces.harkonnen / c : 0))
                setTroopByte(id, World.tBits, troopByte(id, World.tBits) | 0x40)
                DuneEngine.shared.logger.log(.info, "Troops: troop \(id) reports \(c) Harkonnen troops at place \(index)")
            }
        }
        if Int(locationByte(index, 9)) != id && e > s / 2 && Int(lcgRand() & 0x3F) >= s {
            troopCaptured(id)
        }
    }


    // MARK: Battle arithmetic

    /// seg000:342d. `withPaul`: as an attacking troop at Paul's place (6efd).
    func troopStrength(_ id: Int, withPaul: Bool = false) -> Int {
        let m = withPaul
            ? min(troopMotivation(id) + (b(0xFA) != 0 ? 20 : 0) + 30, 100)
            : motivationModifier(id)
        let q = min(255, 2 * m + Int(troopByte(id, World.tArmy)))
        let population = Int(troopByte(id, World.tPopulation))
        let base = q * population / 16
        let e = troopByte(id, World.tEquipment)
        let multiplier = 1 + (e & 0x20 != 0 ? 2 : 0) + (e & 0x10 != 0 ? 4 : 0) + (e & 0x08 != 0 ? 8 : 0) + (e & 0x04 != 0 ? 16 : 0)
        var s = min(255, base * multiplier / 256)
        if s == 0 && population != 0 { s = 1 }
        return s
    }

    /// seg000:33d9: above 0x80 when the Fremen are stronger; the Fremen win
    /// a roll with probability balance / 256.
    static func battleBalance(harkonnen h: Int, fremen f: Int) -> UInt8 {
        if f >= h { return UInt8(h != 0 ? min(252, 128 * f / h) : 252) }
        return UInt8(256 - (f != 0 ? min(252, 128 * h / f) : 252))
    }

    /// seg000:33be: the strength of the live troops on each side, stored
    /// for the dialogue conditions (ds:94, ds:96, ds:9C).
    @discardableResult
    func battleForces(at index: Int) -> (balance: UInt8, harkonnen: Int, fremen: Int) {
        var h = 0, f = 0
        for t in troopsAt(index) where isLive(t.id) {
            if isHarkonnen(t.id) { h += troopStrength(t.id) } else { f += troopStrength(t.id) }
        }
        let balance = World.battleBalance(harkonnen: h, fremen: f)
        setW(0x94, UInt16(truncatingIfNeeded: h))
        setW(0x96, UInt16(truncatingIfNeeded: f))
        setB(0x9C, balance)
        return (balance, h, f)
    }

    /// seg000:758d: the byte 255 - 2a wraps above army skill 127, as in the
    /// original.
    private func battleLoss(_ x: Int, _ id: Int) -> Int {
        let k = Int(UInt8(truncatingIfNeeded: 255 - 2 * Int(troopByte(id, World.tArmy))))
        let v = x * k
        return min(Int(troopByte(id, World.tPopulation)), v >= 65536 ? 255 : v / 256)
    }

    /// location_has_battle (seg000:627e): a raid's battle flag, or Fremen
    /// attacking a hostile place.
    func placeInBattle(_ index: Int) -> Bool {
        guard index >= 0 && index < locationCount else { return false }
        if location(index).status & World.statusBattle != 0 { return true }
        if friendlyPlace(index) { return false }
        return countHostiles(index).attacking > 0
    }

    /// The map's "Battle:" gauge (seg000:60f8), 128 when even, above when
    /// the Fremen do better: f = 256 P_F / (P_F + K_F) over the live
    /// attackers (population, Fremen killed), h = 256 P_H / (P_H + K_H)
    /// (Harkonnen population, Harkonnens killed); 128 + 128 (f - h) / max.
    /// The panel draws sprite 0x8E + (gauge + 15) / 32.
    func battleGauge(at index: Int) -> UInt8 {
        var pf = 0, kf = 0, ph = 0, kh = 0
        for t in troopsAt(index) where isLive(t.id) {
            let population = Int(troopByte(t.id, World.tPopulation))
            if isHarkonnen(t.id) {
                ph += population
            } else if troopByte(t.id, World.tOccupation) & 0x0F == TroopJob.attacking {
                pf += population
                kf += Int(troopWord(t.id, World.tDepE))
                kh += Int(troopWord(t.id, World.tDepC))
            }
        }
        let f = pf + kf > 0 ? 256 * pf / (pf + kf) : 0
        let h = ph + kh > 0 ? 256 * ph / (ph + kh) : 0
        let top = max(f, h)
        let gauge = top > 0 ? 128 + 128 * (f - h) / top : 128
        return UInt8(min(255, max(0, gauge)))
    }


    // MARK: Battle rounds

    /// seg000:668f: the items stay in the place's stock.
    private func troopCaptured(_ id: Int) {
        setTroopByte(id, World.tOccupation, troopByte(id, World.tOccupation) | 0x20)
        setTroopByte(id, World.tEquipment, 0)
        setTroopWord(id, World.tTime, w(World.gameTime))
        changeCharisma(-4)
        DuneEngine.shared.logger.log(.info, "Battle: troop \(id) is captured")
    }

    /// seg000:751d. n is the Fremen troop count of the place last staged
    /// for the conditions (ds:60), normally Paul's: a quirk kept from the
    /// original.
    private func harkonnenStrike(_ id: Int, _ index: Int, _ h: Int) {
        let n = Int(b(0x60))
        let loss = battleLoss(n != 0 ? h / n : h, id)
        setTroopWord(id, World.tDepE, troopWord(id, World.tDepE) &+ UInt16(loss))
        let population = Int(troopByte(id, World.tPopulation)) - loss
        setTroopByte(id, World.tPopulation, UInt8(truncatingIfNeeded: population))
        if population != 0 { return }
        setTroopByte(id, World.tPopulation, UInt8((lcgRandMasked(0x7F) & 0x7F) + 30))
        troopCaptured(id)
        if countHostiles(index).attacking == 0 { battleLost(index) }
    }

    /// seg000:73ef and 7552: the troop hits every live Harkonnen troop
    /// there. Returns true when the battle is won.
    private func fremenStrike(_ id: Int, _ index: Int) -> Bool {
        let ids = troopsAt(index).map { $0.id }
        let c = ids.filter { isHarkonnen($0) && isLive($0) }.count
        if c == 0 {
            battleWon(index)
            return true
        }
        let x = min(255, troopStrength(id) / c + 1)
        var killed = 0
        var left = false
        for k in ids where isHarkonnen(k) && isLive(k) {
            let loss = battleLoss(x, k)
            let population = Int(troopByte(k, World.tPopulation)) - loss
            setTroopByte(k, World.tPopulation, UInt8(truncatingIfNeeded: population))
            killed += loss
            if population != 0 {
                left = true
                continue
            }
            setTroopByte(k, World.tOccupation, troopByte(k, World.tOccupation) | 0x20)
            setTroopByte(k, World.tBits, troopByte(k, World.tBits) | 0x10)
            if lcgRandMasked(3) == 0 {
                // The atomics stay in the fort's stock, the other items are lost.
                setTroopByte(k, World.tEquipment, troopByte(k, World.tEquipment) & ~0x04)
                registerEquipment(k, index, -1)
                setTroopByte(k, World.tEquipment, 0)
            }
        }
        setTroopWord(id, World.tDepC, troopWord(id, World.tDepC) &+ UInt16(truncatingIfNeeded: killed))
        if !left {
            battleWon(index)
            return true
        }
        return false
    }

    /// callback_troop_location_for_troop_occupation_attacking
    /// (seg000:739e): one roll for an attacking troop this period.
    func attackTick(_ id: Int, _ index: Int) {
        if index == World.harkonnenPalaceIndex {
            palaceFalls()
            return
        }
        setB(World.noRaid, b(World.noRaid) | 1)
        let forces = battleForces(at: index)
        if forces.harkonnen == 0 {
            battleWon(index)
            return
        }
        if Int(lcgRand() & 0xFF) >= Int(forces.balance) {
            harkonnenStrike(id, index, forces.harkonnen)
        } else {
            _ = fremenStrike(id, index)
        }
    }

    /// MASSIVE ATTACK (seg000:7317): one roll decides the side that
    /// strikes, repeated up to 16 rounds, no game time passes; ds:98 / ds:9A
    /// keep the strength each side lost. Then Paul's battle is checked
    /// again (1b8d -> 1bec): a lost battle ends the game (pendingEnding
    /// 179). Returns true when the place was won. The UI calls it from the
    /// battle room's MASSIVE ATTACK row, then redraws or shows the ending.
    @discardableResult
    func massiveAttack(at index: Int) -> Bool {
        var forces = battleForces(at: index)
        let h0 = forces.harkonnen, f0 = forces.fremen
        let harkonnensStrike = Int(lcgRand() & 0xFF) >= Int(forces.balance)
        DuneEngine.shared.logger.log(.info, "Battle: massive attack at place \(index), balance \(forces.balance), \(harkonnensStrike ? "the Harkonnens" : "the Fremen") strike")
        var won = false
        var round = 0
        while round < 16 && forces.harkonnen != 0 && forces.fremen != 0 && !won {
            for t in troopsAt(index) where !won {
                let occupation = troopByte(t.id, World.tOccupation)
                if isHarkonnen(t.id) || occupation & 0xE0 != 0 || occupation & 0x0F != TroopJob.attacking { continue }
                if harkonnensStrike {
                    harkonnenStrike(t.id, index, forces.harkonnen)
                } else {
                    won = fremenStrike(t.id, index)
                }
            }
            if !won { forces = battleForces(at: index) }
            round += 1
        }
        let h = won ? 0 : forces.harkonnen
        setW(0x98, UInt16(truncatingIfNeeded: h0 >= h ? h0 - h : 0))
        setW(0x9A, UInt16(truncatingIfNeeded: f0 >= forces.fremen ? f0 - forces.fremen : 0))
        battlePeriodStep()
        return won
    }

    /// FIGHT FOR A WHOLE DAY (seg000:0fc5): up to 16 periods pass, every
    /// attacking troop rolling each period, until Paul's battle is over
    /// (ds:2B = 0) or an ending is pending. Returns the periods run. The
    /// UI calls it from the battle room's row, then redraws the room.
    @discardableResult
    func fightWholeDay() -> Int {
        var periods = 0
        while periods < 16 && b(World.battleHere) != 0 && pendingEnding == nil {
            GameState.shared.passPeriods(1)
            periods += 1
        }
        return periods
    }


    // MARK: Battles won and lost

    /// seg000:75af over the hired troops.
    private func afterBattleWonHired(_ index: Int, fortress: Bool) {
        for t in troopsAt(index) {
            let id = t.id
            let occupation = troopByte(id, World.tOccupation)
            if isHarkonnen(id) || occupation & 0x80 != 0 { continue }
            if id == World.prospectorTroop {
                setTroopByte(id, World.tOccupation, occupation & ~0x20)
                continue
            }
            if occupation & 0x20 != 0 {
                setTroopByte(id, World.tOccupation, 0x22) // apologizes for being captured
                continue
            }
            setTroopByte(id, World.tBits, troopByte(id, World.tBits) | (fortress ? 0x20 : 0))
            setTroopByte(id, World.tBits + 1, troopByte(id, World.tBits + 1) | 0x04) // 0x400: has fought at a fortress
            setTroopByte(id, World.tMotivation, UInt8(min(100, troopMotivation(id) + 4)))
            setTroopByte(id, World.tArmy, UInt8(min(0x5F, Int(troopByte(id, World.tArmy)) + 3)))
            applyJob(id, TroopJob.militaryTraining)
        }
    }

    /// seg000:7429 and, for a fortress, location_battle_won_for_fortress
    /// (7443): Atreides land round it, charisma + 4, the fort held until it
    /// becomes a sietch two days later, its Harkonnens freed or gone.
    private func battleWon(_ index: Int) {
        if index != currentLocation {
            queueVision(7, location: World.placeOffset(index)) // needs Paul-events bit 0
        }
        let l = location(index)
        if l.type < Location.fortressMin {
            setLocationByte(index, 10, locationByte(index, 10) & ~World.statusBattle)
            afterBattleWonHired(index, fortress: false)
        } else {
            paintArea(index, stage: 0x20, radius: 5)
            setLocationByte(index, 11, UInt8(truncatingIfNeeded: (w(World.gameTime) >> 4) &+ 2))
            changeCharisma(4)
            for id in 1...World.troopCount where troopExists(id) && troopByte(id, World.tOccupation) & 0xA0 == 0 {
                setTroopByte(id, World.tMotivation, UInt8(min(100, troopMotivation(id) + 1)))
            }
            setLocationByte(index, 10, locationByte(index, 10) | World.statusHeld)
            afterBattleWonHired(index, fortress: true)
            // seg000:75ea: the fort's Harkonnens become free Fremen while
            // there is a slot below 8; the others leave the game.
            for t in troopsAt(index) {
                let id = t.id
                if !isHarkonnen(id) || troopByte(id, World.tOccupation) & 0x80 == 0 { continue }
                unlinkTroop(id)
                setTroopByte(id, World.tBits, troopByte(id, World.tBits) & ~0x80)
                if linkTroop(id, index) >= 8 {
                    removeFromPlay(id)
                    continue
                }
                let r = lcgRandMasked(0x0F7F)
                let s = lcgRandMasked(0x1F1F) &+ 0x0A0A
                setTroopByte(id, World.tOccupation, 0xA0)
                setTroopByte(id, World.tPopulation, UInt8(truncatingIfNeeded: (r & 0x7F) + 0x64))
                setTroopByte(id, World.tMotivation, UInt8(truncatingIfNeeded: ((r >> 8) & 0x0F) + 0x14))
                setTroopByte(id, 0x16, UInt8(truncatingIfNeeded: s))
                setTroopByte(id, World.tArmy, UInt8(truncatingIfNeeded: s >> 8))
                setTroopByte(id, World.tEquipment, 0)
                setTroopByte(id, World.tBits, troopByte(id, World.tBits) & ~0x10)
            }
        }
        // seg000:7479: perhaps one captive raider; the other Harkonnens leave.
        let keep = lcgRand() & 3 == 0 ? 1 : 0
        var kept = 0
        for t in troopsAt(index) {
            let id = t.id
            if !isHarkonnen(id) || troopByte(id, World.tOccupation) & 0x80 == 0 { continue }
            if kept < keep {
                kept += 1
                setTroopByte(id, World.tOccupation, 0xAC)
                setTroopByte(id, World.tBits, troopByte(id, World.tBits) | 0x10)
                setTroopByte(id, World.tPopulation, 0)
                setTroopByte(id, World.tEquipment, 0)
            } else {
                removeFromPlay(id)
            }
        }
        DuneEngine.shared.logger.log(.info, "Battle: place \(index) is won, charisma \(b(World.charisma))")
        // accumulate_harkonnen_spice_production (1cda): with only the
        // palace left the final attack begins.
        let hostile = (0..<locationCount).filter { !friendlyPlace($0) }.count
        if hostile <= 1 && b(World.finalAttack) == 0 {
            setB(World.finalAttack, 1)
            setRawB(0xFF7, rawB(0xFF7) & 0xFD)
            setRawB(0x1007, rawB(0x1007) & 0xFD)
            DuneEngine.shared.logger.log(.info, "Battle: only the Harkonnen palace is left, final attack stage 1")
        }
    }

    /// seg000:74b6: lost with Paul there, he dies (ds:46d9 = 6: ending
    /// COMMAND 179); elsewhere a sietch becomes a fortress, the Fremen
    /// there are captured and the land round it turns Harkonnen.
    private func battleLost(_ index: Int) {
        setLocationByte(index, 10, locationByte(index, 10) & ~World.statusBattle)
        if index == currentLocation {
            pendingEnding = 179
            DuneEngine.shared.logger.log(.info, "Battle: lost at place \(index) with Paul there")
            return
        }
        let l = location(index)
        if l.type < Location.fortressMin {
            setLocationByte(index, 8, (l.type & 7) + Location.fortressMin)
            setB(World.sietchesAvailable, b(World.sietchesAvailable) &- 1)
        }
        for t in troopsAt(index) {
            if isHarkonnen(t.id) {
                setTroopByte(t.id, World.tBits, troopByte(t.id, World.tBits) | 0x10)
            } else {
                setTroopByte(t.id, World.tOccupation, troopByte(t.id, World.tOccupation) | 0x20)
            }
        }
        paintArea(index, stage: 0x30, radius: 5)
        setLocationByte(index, 10, locationByte(index, 10) & ~(0x01 | World.statusHeld))
        DuneEngine.shared.logger.log(.info, "Battle: place \(index) is lost")
    }

    /// seg000:71ef (job 4), with the fortress conversion of 6e20 on a new
    /// day: a held fort becomes a sietch from the day stored at its byte
    /// 11; then the army skill grows at a pace set by the equipment and
    /// the gap to the place's mean (160 with Gurney there).
    func militaryTraining(_ id: Int, _ index: Int) {
        let status = locationByte(index, 10)
        if hour == 0 && status & World.statusHeld != 0 {
            let delta = UInt8(truncatingIfNeeded: Int(w(World.gameTime) >> 4) - Int(locationByte(index, 11)))
            if delta != 254 && delta != 255 {
                setLocationByte(index, 10, status & ~World.statusHeld)
                setLocationByte(index, 8, locationByte(index, 8) & 7)
                setB(World.sietchesAvailable, b(World.sietchesAvailable) &+ 1)
                for t in troopsAt(index) where troopByte(t.id, World.tBits) & 0x20 != 0 {
                    setTroopWord(t.id, World.tSpeech, troopWord(t.id, World.tSpeech) | 0x1000)
                }
                setLocationByte(index, 11, 5)
                DuneEngine.shared.logger.log(.info, "Battle: fortress \(index) becomes a sietch")
            }
        }
        setTroopByte(id, World.tBits + 1, troopByte(id, World.tBits + 1) & ~0x02)
        if locationByte(index, 10) & 0x04 != 0 { return } // saboteurs (725f, not ported)
        let countdown = Int16(bitPattern: troopWord(id, World.tDepC) &- 1)
        setTroopWord(id, World.tDepC, UInt16(bitPattern: countdown))
        if countdown >= 0 { return }
        var mean = 0, n = 0
        for t in troopsAt(index) {
            let occupation = troopByte(t.id, World.tOccupation)
            if !isHarkonnen(t.id) && occupation & 0xE0 == 0 && occupation & 0x0F == TroopJob.militaryTraining {
                mean += Int(troopByte(t.id, World.tArmy))
                n += 1
            }
        }
        let army = Int(troopByte(id, World.tArmy))
        mean = n != 0 ? mean / n : army
        if Int(rawB(World.gurneyPlace)) == index + 1 {
            mean = 160
            setTroopByte(id, World.tBits + 1, troopByte(id, World.tBits + 1) | 0x08)
        }
        let e = troopByte(id, World.tEquipment)
        let k = e & 0x0C != 0 ? 200 : e & 0x10 != 0 ? 250 : e & 0x20 != 0 ? 300 : 400
        let gap = mean > army ? mean - army : 0
        setTroopWord(id, World.tDepC, UInt16(k / (2 * gap + max(motivationModifier(id), 30))))
        setTroopByte(id, World.tArmy, UInt8(min(army + 1, 95)))
    }


    // MARK: Paul at a battle

    /// Paul is in a battle (ds:2B, night_attack_stage): the first room
    /// offers SEE DUNE MAP, MASSIVE ATTACK, FIGHT FOR A WHOLE DAY and CALL
    /// A WORM (greyed before phase 0x4F), no ornithopter.
    var paulInBattle: Bool { b(World.battleHere) != 0 }

    /// location_related_to_dying_if_arriving_at_fortress (seg000:503c):
    /// the UI calls it on every arrival (ornithopter, worm, walk) before
    /// showing the place. A place in battle, or hostile with Fremen
    /// attacking it, starts Paul's battle (ds:2B = 1, ds:FD the gauge);
    /// hostile with live Harkonnens and nobody attacking, Paul is shot
    /// (pendingEnding = 177).
    @discardableResult
    func nightAttackCheck(at index: Int) -> ArrivalOutcome {
        setB(World.battleGaugeByte, 0)
        setB(World.battleHere, 0)
        guard index >= 0 && index < locationCount else { return .safe }
        let l = location(index)
        let hostiles = countHostiles(index)
        let friendly = friendlyPlace(index)
        if l.status & World.statusBattle != 0 || (!friendly && hostiles.attacking > 0) {
            setB(World.battleHere, 1)
            setB(World.battleGaugeByte, battleGauge(at: index) | 1)
            DuneEngine.shared.logger.log(.info, "Arrival: place \(index) is in battle, Paul joins it")
            return .battle
        }
        if !friendly && hostiles.harkonnen > 0 {
            pendingEnding = 177
            DuneEngine.shared.logger.log(.info, "Arrival: \(hostiles.harkonnen) Harkonnen troop(s) at place \(index), Paul is shot")
            return .shot
        }
        return .safe
    }

    /// night_attack_period_step (seg000:1bec), each period and after a
    /// massive attack: while Paul is in a battle it is checked again; a
    /// death pending there becomes the battle's (COMMAND 179), and a
    /// battle over clears ds:2B (the UI then redraws the room).
    func battlePeriodStep() {
        guard b(World.battleHere) != 0 else { return }
        if nightAttackCheck(at: currentLocation) == .shot { pendingEnding = 179 }
        if b(World.battleHere) == 0 {
            DuneEngine.shared.logger.log(.info, "Battle: the battle at place \(currentLocation) is over")
        }
    }

    /// The part of prepare_location_data_for_condit (seg000:331e / 34a5)
    /// the battles read: ds:60, the settled Fremen troops of the place
    /// (not captured, not moving, not an unhired 0x80).
    func stageFremenCount(_ index: Int) {
        var count = 0
        for t in troopsAt(index) {
            let occupation = troopByte(t.id, World.tOccupation)
            if occupation & 0x60 != 0 || isHarkonnen(t.id) || occupation == 0x80 { continue }
            count += 1
        }
        setB(0x60, UInt8(truncatingIfNeeded: count))
    }


    // MARK: The Harkonnen captain

    /// A defeated Harkonnen troop at the place (the captain, seg000:316e),
    /// nil if none. He stands in room 3 of a fort in battle.
    func captainTroop(at index: Int) -> Int? {
        troopsAt(index).first { isHarkonnen($0.id) && !isLive($0.id) }?.id
    }

    /// seg000:932e: before the captain speaks, the fort he knows of: the one
    /// kept in his record (+0x0C), or else the nearest hidden fort within
    /// 30 cells, which he remembers; its pointer goes to ds:11CE, which his
    /// dialogue event 8 reveals. (The rest of 331e's staging is not ported.)
    func prepareCaptain() {
        guard let id = captainTroop(at: currentLocation) else { return }
        var known = troopWord(id, World.tDepC)
        if known == 0 {
            guard let fort = nearestHiddenHarkonnen(from: currentLocation), fort.distance < 0x1E else { return }
            known = World.placeOffset(fort.index)
            setTroopWord(id, World.tDepC, known)
        }
        if Int(known) >= Location.tableOffset { setW(0x11CE, known) }
        DuneEngine.shared.logger.log(.info, "Story: the Harkonnen captain (troop \(id)) knows of place \((Int(known) - Location.tableOffset) / Location.recordSize)")
    }


    // MARK: Worms

    /// CALL A WORM (seg000:42d1) is greyed while the phase is below 0x4F
    /// (0x4C is Leto's death). It is offered in the desert and in room 1
    /// of every place, the battle menu included.
    var canCallWorm: Bool { b(World.phase) >= 0x4F }

    /// GO THERE RIDING A WORM in the map's place popup (seg000:50ea): once
    /// a worm has been ridden (ds:0A bit 6, set by phase 0x50), and not in
    /// ornithopter mode.
    var canTravelByWorm: Bool { b(World.paulEvents) & 0x40 != 0 }

    /// Departure on a worm (map_confirm_travel_and_close, seg000:4703 ->
    /// 4795, travel mode 2): calling a worm ends Paul's battle (ds:2B = 0);
    /// the first ride sets phase 0x50 (ds:0A bit 6, charisma + 40). No
    /// ornithopter is taken and the Harkonnen-zone check (4182) does not
    /// run, so a worm is never shot down. The UI plays VER / SN8 and the
    /// worm-suit music, and calls nightAttackCheck on arrival.
    func rideWorm() {
        setB(World.battleHere, 0)
        Story.shared.setGamePhase(0x50)
        DuneEngine.shared.logger.log(.info, "Travel: riding a worm")
    }


    // MARK: Final attack

    /// seg000:1243: at least 10 000 men with atomics training (job 4) at
    /// locations 2-4, the three Arrakeen fortresses by the palace.
    func finalAttackReady() -> Bool {
        var men = 0
        for index in 2...4 {
            for t in troopsAt(index) {
                let occupation = troopByte(t.id, World.tOccupation)
                if !isHarkonnen(t.id) && occupation & 0x80 == 0 && occupation & 0x0F == TroopJob.militaryTraining
                    && occupation & 0x60 == 0 && troopByte(t.id, World.tEquipment) & 0x04 != 0 {
                    men += Int(troopByte(t.id, World.tPopulation))
                }
            }
        }
        return men >= 1000
    }

    /// seg000:9f40 -> 1243: any line of Thufir at stage 4 with 10 000 men
    /// and atomics round the palace moves the final attack to stage 5.
    func thufirSpeaks() {
        if b(World.finalAttack) == 4 && finalAttackReady() {
            setB(World.finalAttack, 5)
            DuneEngine.shared.logger.log(.info, "Story: enough men round the palace, final attack stage 5")
        }
    }

    /// Stilgar's event 9 (seg000:2d2c / 2d62): the final attack. Stage + 1
    /// (the shipments stop); the hired troops with atomics training at
    /// locations 2-4 march on the Harkonnen palace. Returns them.
    @discardableResult
    func finalAttackTroops() -> [Int] {
        setB(World.finalAttack, b(World.finalAttack) &+ 1)
        var ids: [Int] = []
        for index in 2...4 {
            for t in troopsAt(index) where !isHarkonnen(t.id) && troopByte(t.id, World.tOccupation) == TroopJob.militaryTraining
                && troopByte(t.id, World.tEquipment) & 0x04 != 0 {
                ids.append(t.id)
            }
        }
        for id in ids where issueMoveOrder(troop: id, to: World.harkonnenPalaceIndex) {
            troopTravelStep(id)
        }
        DuneEngine.shared.logger.log(.info, "Story: the final attack, \(ids.count) troop(s) with atomics march on the palace")
        return ids
    }

    /// seg000:73a9: no battle at the palace. The troops there train, its
    /// Harkonnens leave, all Harkonnen land turns Atreides; vision 0x0A.
    /// Afterwards Paul can enter; room 2 of the Harkonnen palace is the
    /// Emperor's scene (phase 0xC8).
    private func palaceFalls() {
        let palace = World.harkonnenPalaceIndex
        setB(World.finalAttack, b(World.finalAttack) &+ 1)
        for t in troopsAt(palace) {
            if isHarkonnen(t.id) || troopByte(t.id, World.tOccupation) & 0x80 != 0 {
                removeFromPlay(t.id)
            } else {
                applyJob(t.id, TroopJob.militaryTraining)
            }
        }
        for i in 0..<map.count where map[i] & 0x30 == 0x30 {
            map[i] = (map[i] & 0xCF) | 0x20
        }
        queueVision(0x0A, location: World.placeOffset(palace))
        DuneEngine.shared.logger.log(.info, "Battle: the Harkonnen palace falls, final attack stage \(b(World.finalAttack))")
    }

    /// Stilgar's event 8 (seg000:2ccf): Paul has heard of the Water of
    /// Life; if he accepted (ds:9F = 1) he drinks it: 1 he lives (charisma
    /// at least 100; three periods pass), 2 he dies (pendingEnding = 176);
    /// 0 no drink.
    @discardableResult
    func stilgarWaterOfLife() -> Int {
        setB(World.paulEvents, b(World.paulEvents) | 8)
        guard b(World.choice) == 1 else { return 0 }
        if b(World.charisma) < 0x64 {
            pendingEnding = 176
            DuneEngine.shared.logger.log(.info, "Story: Paul drinks the Water of Life and dies")
            return 2
        }
        setB(World.paulEvents, b(World.paulEvents) | 2)
        setB(0xD5, 0xFF)
        GameState.shared.passPeriods(3)
        DuneEngine.shared.logger.log(.info, "Story: Paul drinks the Water of Life")
        return 1
    }
}
