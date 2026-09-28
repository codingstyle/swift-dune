//
//  Troops.swift
//  SwiftDune
//
//  Fremen and Harkonnen troops: rallying (WORK FOR ME), the charisma check,
//  occupations, spice mining and prospecting, and what runs each period.
//  Troop records are 27 bytes at 0x8AA + 27 * (id - 1), 68 of them.
//
//  Port of the ScummVM Dune engine's world.cpp / troops.cpp / battle.cpp
//  (runPeriod, rallyTroop, setTroopOccupation, mineSpice, prospect,
//  changeCharisma). Marches, military training, espionage and attacks are
//  in Battles.swift, the ecology jobs in Ecology.swift. Not ported: the
//  harvester breakdowns, saboteurs, the small-troop merge (seg000:6d19),
//  the skill decay every 4 days (6d7b) and the Harkonnen raids (1f64).
//

import Foundation


enum TroopJob {
    static let spiceMining: UInt8 = 0x00
    static let prospecting: UInt8 = 0x01
    static let waitingForOrders: UInt8 = 0x02
    static let militaryTraining: UInt8 = 0x04
    static let espionage: UInt8 = 0x05
    static let attacking: UInt8 = 0x06
    static let irrigation: UInt8 = 0x08
    static let windTrap: UInt8 = 0x09
    static let bulbGrowing: UInt8 = 0x0A
    static let stopped: UInt8 = 0x10
}


extension World {
    static let spiceStock = 0xA0        // word: palace stock in 10 kg batches
    static let fremenTroops = 0x28      // rallied troops
    static let bulbPlace = 62

    private func troopOffset(_ id: Int) -> Int { World.troopTable + World.troopSize * (id - 1) }
    func troopByte(_ id: Int, _ byte: Int) -> UInt8 { vars[troopOffset(id) + byte] }
    func setTroopByte(_ id: Int, _ byte: Int, _ value: UInt8) { setRawB(troopOffset(id) + byte, value) }
    func troopWord(_ id: Int, _ byte: Int) -> UInt16 { rawW(troopOffset(id) + byte) }
    func setTroopWord(_ id: Int, _ byte: Int, _ value: UInt16) {
        setRawB(troopOffset(id) + byte, UInt8(value & 0xFF))
        setRawB(troopOffset(id) + byte + 1, UInt8(value >> 8))
    }
    func locationByte(_ index: Int, _ byte: Int) -> UInt8 {
        vars[Location.tableOffset + index * Location.recordSize + byte]
    }
    func setLocationByte(_ index: Int, _ byte: Int, _ value: UInt8) {
        setRawB(Location.tableOffset + index * Location.recordSize + byte, value)
    }
    func locationWord(_ index: Int, _ byte: Int) -> UInt16 {
        rawW(Location.tableOffset + index * Location.recordSize + byte)
    }
    func setLocationWord(_ index: Int, _ byte: Int, _ value: UInt16) {
        setLocationByte(index, byte, UInt8(value & 0xFF))
        setLocationByte(index, byte + 1, UInt8(value >> 8))
    }

    func troopExists(_ id: Int) -> Bool { id >= 1 && id <= World.troopCount && troopByte(id, 0) != 0 }
    func troopMotivation(_ id: Int) -> Int { Int(troopByte(id, 21)) }
    func troopSpiceSkill(_ id: Int) -> Int { Int(troopByte(id, 22)) }
    func troopMen(_ id: Int) -> Int { Int(troopByte(id, 26)) * 10 }

    /// The location a troop is at (byte 4: its record's ds offset).
    func troopPlace(_ id: Int) -> Int? {
        let offset = Int(troopWord(id, 4))
        guard offset >= Location.tableOffset else { return nil }
        let index = (offset - Location.tableOffset) / Location.recordSize
        return index < locationCount ? index : nil
    }

    /// The first Fremen troop here that is hired (or not).
    func localTroop(hired: Bool) -> Int? {
        troopsAt(currentLocation).first { !$0.harkonnen && $0.hired == hired }?.id
    }

    /// seg000:6efd.
    func motivationModifier(_ id: Int) -> Int {
        let job = troopByte(id, 3) & 0x0F
        var m = troopMotivation(id) + (b(0xFA) != 0 ? 20 : 0)
        if job == TroopJob.attacking {
            if troopPlace(id) == currentLocation { m = min(m + 30, 100) }
        } else if job & 0x0E == 8 {
            m = 100
        } else {
            m = min(m, 100)
        }
        let p = b(World.phase)
        if p >= 0x64 && p < 0x68 { m = max(m - 40, 10) }
        return m
    }

    /// WORK FOR ME's charisma check (seg000:95c1).
    func troopAgreesToFollow(_ id: Int) -> Bool {
        var harkonnen = 0
        for i in 1...World.troopCount where troopExists(i) && troopByte(i, 16) & 0x80 != 0 {
            harkonnen += troopMen(i) / 10
        }
        let charisma = Int(b(World.charisma))
        return harkonnen < 1000 || charisma > 100 || (100 - charisma) / 4 <= motivationModifier(id)
    }

    /// Charisma 0...200; crossing a multiple of 4 moves every active troop's
    /// motivation by the change of charisma / 4 (seg000:6f78).
    func changeCharisma(_ delta: Int) {
        let before = Int(b(World.charisma))
        let after = min(max(before + delta, 0), 200)
        setB(World.charisma, UInt8(after))
        let spill = after / 4 - before / 4
        guard spill != 0 else { return }
        for id in 1...World.troopCount where troopExists(id) && troopByte(id, 3) & 0xA0 == 0 {
            setTroopByte(id, 21, UInt8(min(max(troopMotivation(id) + spill, 0), 100)))
        }
    }

    /// troop_rally_troop (seg000:66ce). Returns the phase the story should
    /// move to (0x4C once var 0x1178 troops are rallied), if any.
    @discardableResult
    func rallyTroop(_ id: Int) -> UInt8? {
        guard troopExists(id), troopByte(id, 3) & 0x80 != 0, troopByte(id, 16) & 0x80 == 0 else { return nil }
        setB(World.fremenTroops, b(World.fremenTroops) &+ 1)
        var requested: UInt8?
        if b(World.fremenTroops) >= b(0x1178) && b(World.phase) < 0x4C { requested = 0x4C }
        changeCharisma(1)
        setTroopByte(id, 3, (troopByte(id, 3) & 0x20) | TroopJob.waitingForOrders)
        setTroopWord(id, 0x0A, w(World.gameTime))
        setTroopWord(id, 0x0C, 0)
        setTroopWord(id, 0x0E, 0)
        setTroopByte(id, 0x14, UInt8(truncatingIfNeeded: w(World.gameTime) >> 4))
        if let place = troopPlace(id), locationByte(place, 11) == 0 {
            // seg000:6704: the first troop rallied at a place paints its Atreides disc.
            setLocationByte(place, 11, 2)
            paintArea(place, stage: 0x20, radius: 2)
        }
        DuneEngine.shared.logger.log(.info, "Troops: troop \(id) rallied, \(b(World.fremenTroops)) Fremen troops, charisma \(b(World.charisma))")
        return requested
    }

    /// seg000:6acb: store the job, clear the refusals, restart its clocks.
    func setTroopOccupation(_ id: Int, _ job: UInt8) {
        guard troopExists(id), troopByte(id, 3) & 0x0F != job else { return }
        var occupation = job
        if job == TroopJob.irrigation, let place = troopPlace(id), place == World.bulbPlace, locationByte(place, 26) == 0 {
            occupation = TroopJob.bulbGrowing
        }
        setTroopByte(id, 3, occupation)
        setTroopByte(id, 0x12, troopByte(id, 0x12) & 0xCF)
        if occupation != TroopJob.waitingForOrders {
            setTroopByte(id, 0x13, troopByte(id, 0x13) | UInt8(truncatingIfNeeded: 0x20 << ((occupation & 0x0F) >> 2)))
        }
        var bits = troopWord(id, 0x10) & ~0x100
        if occupation == TroopJob.spiceMining {
            if miningViable(id) { bits |= 0x100 } else { setTroopByte(id, 3, troopByte(id, 3) | TroopJob.stopped) }
        } else if occupation != TroopJob.waitingForOrders {
            bits |= 0x100
        }
        setTroopWord(id, 0x10, bits)
        setTroopWord(id, 0x0A, w(World.gameTime))
        setTroopWord(id, 0x0C, 0)
        setTroopWord(id, 0x0E, 0)
    }

    private func miningViable(_ id: Int) -> Bool {
        guard let place = troopPlace(id) else { return false }
        let l = location(place)
        return troopWord(id, 0x10) & 0x200 == 0 && troopWord(id, 0x12) & 0x30 == 0
            && l.spiceDensity >= 1 && (l.status ^ 0x40) & 0x41 == 0
    }

    /// troop_update_harvest_rate (seg000:708a): kg this period.
    func harvestRate(_ id: Int) -> Int {
        guard let place = troopPlace(id) else { return 0 }
        let l = location(place)
        var product = ((motivationModifier(id) + (troopSpiceSkill(id) & 0xF0)) & 0xFF) * (troopMen(id) / 10)
        if troopByte(id, 25) & 0x80 == 0 { product >>= 2 } // no harvester
        return ((((Int(l.spiceDensity) & 0xF0) + 1) * ((product >> 8) & 0xFF)) >> 7) & 0x1FF
    }

    private func raiseSpiceSkill(_ id: Int, _ amount: Int) {
        setTroopByte(id, 22, UInt8(min(0x5F, troopSpiceSkill(id) + amount)))
    }

    /// seg000:6fe5 (harvester breakdowns and saboteurs not transcribed).
    private func mineSpice(_ id: Int, _ index: Int) {
        guard miningViable(id) else {
            setTroopWord(id, 0x0C, 0)
            setTroopWord(id, 0x0E, 0)
            setTroopByte(id, 3, troopByte(id, 3) | TroopJob.stopped)
            return
        }
        setTroopByte(id, 3, troopByte(id, 3) & ~TroopJob.stopped)
        setTroopWord(id, 0x10, troopWord(id, 0x10) | 0x100)
        let kg = harvestRate(id)
        setTroopWord(id, 0x0C, UInt16(kg))
        let total = troopWord(id, 0x0E)
        setTroopWord(id, 0x0E, total &+ UInt16(kg))
        if ((total &+ UInt16(kg)) ^ total) & 0xFF80 != 0 { raiseSpiceSkill(id, 1) }
        // The stock counts 10 kg batches; the remainder carries over.
        let carried = kg + harvestRemainder
        setW(World.spiceStock, UInt16(min(0xFFFF, Int(w(World.spiceStock)) + carried / 10)))
        harvestRemainder = carried % 10
        let l = location(index)
        if l.spiceAmount > 0 {
            let eaten = kg + Int(locationByte(index, 19))
            setLocationByte(index, 19, UInt8(eaten % Int(l.spiceAmount)))
            let drop = eaten / Int(l.spiceAmount)
            setLocationByte(index, 18, drop >= Int(l.spiceDensity) ? 0 : l.spiceDensity - UInt8(drop))
        }
    }

    /// seg000:70cc.
    private func prospect(_ id: Int, _ index: Int) {
        let l = location(index)
        if l.status & 0x02 != 0 { return } // a battle suspends the job
        if l.status & 0x40 == 0 {
            var duration = troopWord(id, 0x0C)
            if duration == 0 {
                let speed = max(1, troopMotivation(id) + troopSpiceSkill(id))
                duration = UInt16((Int(l.spiceAmount) << 4) / speed)
                setTroopWord(id, 0x0C, duration)
            }
            let elapsed = w(World.gameTime) &- troopWord(id, 0x0A)
            if duration > elapsed {
                if elapsed > 0 { setTroopWord(id, 0x0E, UInt16(Int(elapsed) * 100 / Int(duration))) }
                return
            }
            raiseSpiceSkill(id, 2)
            setLocationByte(index, 10, locationByte(index, 10) | 0x40)
            DuneEngine.shared.logger.log(.info, "Troops: troop \(id) prospected place \(index)")
        }
        setTroopWord(id, 0x0E, 100)
        setTroopByte(id, 3, troopByte(id, 3) | TroopJob.stopped)
    }

    /// run_events_for_current_time_period (seg000:1b23): troop jobs, the
    /// time of day's action, the new day's ecology walk, Harkonnen
    /// production and today's spice, then Paul's battle (1bec). Once the
    /// Harkonnen palace has fallen (ds:C2 >= 7) no troop or time-of-day
    /// event runs any more (seg000:1b5e).
    func runPeriod() {
        let troopEvents = b(0xC2) < 7
        if troopEvents {
            for id in 1..<World.troopCount where troopExists(id) {
                let occupation = troopByte(id, 3)
                // seg000:6c92-6ceb: a marching troop travels (6ced -> 8308).
                if occupation & 0x40 != 0 {
                    if occupation & 0xA0 == 0 || troopWord(id, 0x12) & 0x430 != 0 { troopTravelStep(id) }
                    continue
                }
                if troopWord(id, 0x12) & 0x430 != 0 {
                    if b(0xFA) == 0 { continue }
                    setTroopByte(id, 0x12, troopByte(id, 0x12) & 0xCF)
                    if troopWord(id, 0x12) & 0x400 != 0 { continue }
                }
                if occupation & 0xA0 != 0 { continue }
                guard let index = troopPlace(id) else { continue }
                let harkonnen = troopByte(id, 0x10) & 0x80 != 0
                switch occupation & 0x0F {
                case TroopJob.militaryTraining: if !harkonnen { militaryTraining(id, index) }
                case TroopJob.espionage: if !harkonnen { espionageTick(id, index) }
                case TroopJob.attacking: if !harkonnen && occupation & TroopJob.stopped == 0 { attackTick(id, index) }
                case TroopJob.spiceMining: mineSpice(id, index)
                case TroopJob.prospecting: prospect(id, index)
                case TroopJob.irrigation, TroopJob.windTrap, TroopJob.bulbGrowing:
                    if !harkonnen { runEcologyJob(id, index) }
                default: break
                }
            }
        }
        if troopEvents && hour == 3 {
            // actions_time_in_day_3 (seg000:20a4): the Emperor's shipments.
            let day = shipmentDay()
            if day.ending { pendingEnding = 180 } // "As Paul Atreides failed to respond to my spice demands..."
            addSighting(day.sighting)
        }
        if hour == 8 && shipmentReminderDue {
            queueVision(0x30B) // actions_time_in_day_8 (seg000:1dda)
        }
        if hour == 15 && (rollRandom(2) & 1) == 1 {
            // Every Harkonnen troop of 1..199 (x 10 men) gains ten men.
            for id in 1...World.troopCount where troopExists(id) && troopByte(id, 16) & 0x80 != 0 {
                let men = troopByte(id, 26)
                if men >= 1 && men < 200 { setTroopByte(id, 26, men + 1) }
            }
        }
        if hour == 0 { ecologyNewDay() } // seg000:63f0
        // seg000:1b86 re-stages the current place for the conditions (331e,
        // not ported); ds:60, its Fremen troop count, feeds the battles.
        stageFremenCount(currentLocation)
        if hour == 0 {
            // New day (seg000:1c46): Harkonnen production and today's spice.
            var sum = 0
            for i in 0..<locationCount {
                let l = location(i)
                if (l.type >= Location.fortressMin && l.type <= Location.fortressMax) || l.type == Location.harkonnenPalace || l.hidden {
                    sum += Int(l.spiceDensity) / 8
                }
            }
            setW(0xA8, UInt16(min(0xFFFF, sum + rollRandom(sum / 16 + 1))))
            let stock = w(World.spiceStock)
            setW(0xA6, stock >= w(0x1170) ? stock - w(0x1170) : 0)
            setW(0x1170, stock)
        }
        battlePeriodStep() // night_attack_period_step (seg000:1bec)
    }

    /// The executable's random word at ds:0; its generator is not
    /// transcribed, a 16-bit Galois LFSR stands in (as in ScummVM).
    func rollRandom(_ range: Int) -> Int {
        var r = w(0x00)
        if r == 0 { r = 0xACE1 }
        r = (r >> 1) ^ ((r & 1) != 0 ? 0xB400 : 0)
        setW(0x00, r)
        return range > 0 ? Int(r) % range : Int(r)
    }
}
