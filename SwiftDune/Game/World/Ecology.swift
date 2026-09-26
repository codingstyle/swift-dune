//
//  Ecology.swift
//  SwiftDune
//
//  The ecology route: the live map's stage bits, the ecology troops' jobs
//  (wind trap, bulbs, irrigation), the vegetation discs that turn the land
//  Atreides and take the fortresses without a battle, the new day's walk,
//  the equipment the troops carry, and the new-game pass that ties each
//  place to its map cell and spice field.
//
//  Port of the ScummVM Dune engine's ecology.cpp and world.cpp
//  (prepareNewGame), transcribed there from the CD executable (the seg000
//  addresses below). Location and troop bytes are raw record offsets;
//  ds variables are CD offsets.
//

import Foundation


extension World {
    /// MAP.HSQ's cells as the game keeps them (12,671 save bytes x 4).
    static let mapCells = 50_684
    static let mapCentre = 0x62FC
    static let bulbProgress = 0xEC      // bulb_growing_progress

    // Location record bytes.
    private static let discRadius = 11      // 0x0b, also the day a won fort becomes a sietch
    private static let discLongitude = 12   // word
    private static let discLatitude = 14    // the byte
    private static let discProgress = 15
    private static let density = 18
    private static let bulbs = 26
    private static let water = 27           // water, or the wind trap's assembly progress

    private static let statusVegetation: UInt8 = 0x01
    private static let statusAtreides: UInt8 = 0x08
    private static let statusWindTrap: UInt8 = 0x20


    // MARK: The live map

    /// A new game's map: MAP.HSQ as shipped, each place's cell marked with
    /// bit 6 (seg000:01a1).
    func freshMap() -> [UInt8] {
        var cells = Resource("MAP.HSQ").unpackedData
        if cells.count < World.mapCells {
            cells += [UInt8](repeating: 0, count: World.mapCells - cells.count)
        }
        markPlaceCells(&cells)
        return cells
    }

    func resetMap() {
        map = freshMap()
    }

    /// Marks the places' cells again (bit 6), after a save's stage bits.
    func markPlaceCells() {
        markPlaceCells(&map)
    }

    private func markPlaceCells(_ cells: inout [UInt8]) {
        for i in 0..<locationCount {
            let offset = Int(locationWord(i, 6))
            if offset != 0 && offset < cells.count { cells[offset] |= 0x40 }
        }
    }

    private func tablatWord(_ o: Int) -> Int { Int(tablat[o]) << 8 | Int(tablat[o + 1]) }

    /// The row length in cells at a latitude (TABLAT), 0 when missing.
    func rowCells(_ latitude: Int) -> Int {
        let row = abs(latitude)
        guard (row + 1) * 8 <= tablat.count else { return 0 }
        return 2 * tablatWord(8 * row + 2)
    }

    /// map_func (seg000:b58b): the row by |latitude| from TABLAT (offset,
    /// half the cells), the cell under the longitude rounded. Nil off the map.
    func mapCell(longitude: UInt16, latitude: Int) -> Int? {
        let row = abs(latitude)
        guard (row + 1) * 8 <= tablat.count else { return nil }
        let rowOffset = tablatWord(8 * row)
        let cells = 2 * tablatWord(8 * row + 2)
        guard cells > 0 else { return nil }
        let product = UInt32(longitude) * UInt32(cells)
        var cell = Int(product >> 16) + Int((product >> 15) & 1)
        if cell >= cells { cell -= cells }
        let offset = World.mapCentre + (latitude < 0 ? -rowOffset : rowOffset) + cell
        return offset >= 0 && offset < World.mapCells ? offset : nil
    }

    /// The stage bits (0x30 mask) of the cell under a position.
    func cellStage(longitude: UInt16, latitude: Int) -> UInt8 {
        guard let o = mapCell(longitude: longitude, latitude: latitude), o < map.count else { return 0 }
        return map[o] & 0x30
    }

    /// The filled circle of seg000:64b2: for each row dy of the disc, the
    /// span of cells around the centre's column, wrapping round the row.
    private func forDisc(longitude: UInt16, latitude: Int, radius: Int, limit: Int,
                         _ body: (_ offset: Int, _ cell: inout UInt8) -> Void) {
        let r = radius
        guard r >= 0 else { return }
        for dy in -r...r {
            let lat = latitude + dy
            if lat > limit || lat < -limit { continue }
            let row = abs(lat)
            guard (row + 1) * 8 <= tablat.count else { continue }
            let rowOffset = tablatWord(8 * row)
            let cells = 2 * tablatWord(8 * row + 2)
            guard cells > 0 else { continue }
            let rowStart = World.mapCentre + (lat < 0 ? -rowOffset : rowOffset)
            let product = UInt32(longitude) * UInt32(cells)
            let centre = (Int(product >> 16) + Int((product >> 15) & 1)) % cells
            var half = 0
            while (half + 1) * (half + 1) + dy * dy <= r * r { half += 1 }
            for dx in -half...half {
                let o = rowStart + (((centre + dx) % cells) + cells) % cells
                guard o >= 0 && o < map.count else { continue }
                var cell = map[o]
                body(o, &cell)
                map[o] = cell
            }
        }
    }

    /// seg000:6447 / 644e: the area round a place becomes Harkonnen (0x30)
    /// or Atreides (0x20) land; sprouting cells keep their vegetation.
    func paintArea(_ index: Int, stage: UInt8, radius: Int) {
        let l = location(index)
        forDisc(longitude: l.longitude, latitude: Int(l.latitude), radius: radius, limit: 0x5D) { _, c in
            if c & 0x30 != 0x10 { c = (c & 0xCF) | stage }
        }
    }

    /// compute_area_controlled_percentages (seg000:bfe3): ds:A2 Atreides,
    /// ds:A4 Harkonnen, in percent of the map.
    func computeAreas() {
        var atreides = 0, harkonnen = 0
        for i in 0..<min(0xC5F9, map.count) {
            let s = map[i] & 0x30
            if s == 0x30 { harkonnen += 1 } else if s != 0 { atreides += 1 }
        }
        let all = 0xC5F9 - 0x188 + 1
        setW(0xA2, UInt16(atreides * 100 / all + 1))
        setW(0xA4, UInt16(harkonnen * 100 / all))
    }


    // MARK: New game

    /// The executable's new-game pass (seg000:0169): snap each place to its
    /// map cell, store the cell's offset (bytes 6-7), its MAP2.HSQ spice
    /// field (16) and the field's size (17); then settle every troop on its
    /// place (seg000:01e0) and start from MAP.HSQ as shipped. Verified in
    /// ScummVM against the original floppy's new-game save.
    @discardableResult
    func prepareNewGame() -> Bool {
        let map2 = Resource("MAP2.HSQ").unpackedData
        defer { resetMap() } // a new game's map, the places' cells marked (seg000:01a1)
        guard tablat.count >= 8 * 99, map2.count >= 50_681 else {
            DuneEngine.shared.logger.log(.warn, "World: TABLAT.BIN or MAP2.HSQ missing, spice fields not prepared")
            return false
        }
        // A histogram of MAP2's bytes, each count starting at 7.
        var histogram = [Int](repeating: 7, count: 256)
        for i in 0..<50_681 { histogram[Int(map2[i])] += 1 }
        for i in 0..<locationCount {
            let l = location(i)
            let row = abs(Int(l.latitude))
            guard (row + 1) * 8 <= tablat.count else { continue }
            let rowOffset = tablatWord(8 * row)
            let cells = 2 * tablatWord(8 * row + 2)
            // sub_1b58b: the cell under the longitude, rounded; sub_1b5c5
            // snaps the longitude to that cell's start.
            let product = UInt32(l.longitude) * UInt32(cells)
            let cell = Int(product >> 16) + Int((product >> 15) & 1)
            let offset = World.mapCentre + (l.latitude < 0 ? -rowOffset : rowOffset) + cell
            guard cells > 0, offset >= 0, offset < map2.count else { continue }
            setLocationWord(i, 2, UInt16(truncatingIfNeeded: (UInt32(cell & 0xFFFF) << 16) / UInt32(cells)))
            setLocationWord(i, 6, UInt16(offset))
            setLocationByte(i, 16, map2[offset])
            setLocationByte(i, 17, UInt8(truncatingIfNeeded: histogram[Int(map2[offset])] >> 4))
        }
        // seg000:01e0: each troop of a place gets the place's record and
        // position, and its region (the place's first-name id) in the low
        // nibble of byte 18, bit 7 for the southern regions.
        for i in 0..<locationCount {
            let l = location(i)
            for t in troopsAt(i) {
                let id = t.id
                setTroopWord(id, 4, World.placeOffset(i))
                setTroopWord(id, 6, locationWord(i, 2))
                setTroopWord(id, 8, UInt16(bitPattern: l.latitude))
                let region = l.firstName & 0x0F
                var high = troopByte(id, 18) & 0x70
                if region > 3 { high ^= 0x80 }
                if region > 5 { high ^= 0x80 }
                if region > 9 { high ^= 0x80 }
                setTroopByte(id, 18, high | region)
            }
        }
        DuneEngine.shared.logger.log(.info, "World: spice fields and troops prepared (seg000:0169)")
        return true
    }


    // MARK: Places

    /// location_is_Atreides (seg000:5d36): a sietch or village (type below
    /// 0x28), or a place held by the Atreides (status bit 3).
    func friendlyPlace(_ index: Int) -> Bool {
        let l = location(index)
        return l.type < Location.fortressMin || l.status & World.statusAtreides != 0
    }

    /// seg000:5082 over the place's troops: live Harkonnen troops (byte 16
    /// bit 7) and Fremen attacking it (occupation exactly 6).
    func countHostiles(_ index: Int) -> (harkonnen: Int, attacking: Int) {
        var harkonnen = 0, attacking = 0
        for t in troopsAt(index) {
            let occupation = troopByte(t.id, 3)
            if occupation & 0x20 != 0 { continue }
            if troopByte(t.id, 16) & 0x80 != 0 {
                harkonnen += 1
            } else if occupation == TroopJob.attacking {
                attacking += 1
            }
        }
        return (harkonnen, attacking)
    }


    // MARK: Ecology jobs

    /// seg000:6edd: skill byte 0x16 + class (0 spice, 1 army, 2 ecology),
    /// capped at 0x5F; a new high nibble shows as "ability increased"
    /// (bitfield 0x10 bits 0-1).
    func raiseSkill(_ id: Int, skillClass: Int, _ amount: Int) {
        let before = troopByte(id, 0x16 + skillClass)
        let skill = UInt8(min(0x5F, Int(before) + amount))
        setTroopByte(id, 0x16 + skillClass, skill)
        if (skill ^ before) & 0xF0 != 0 {
            setTroopWord(id, 0x10, (troopWord(id, 0x10) & ~3) | UInt16(skillClass + 1))
        }
    }

    /// One period of an ecology job (seg000:767d bulbs, 7711 wind trap,
    /// 7693 irrigation).
    func runEcologyJob(_ id: Int, _ index: Int) {
        switch troopByte(id, 3) & 0x0F {
        case TroopJob.bulbGrowing:
            // seg000:767d: bulbs where there are none grow over 256 periods
            // (ds:EC), 16 at once; then the troop irrigates.
            if locationByte(index, World.bulbs) == 0 {
                let p = b(World.bulbProgress) &+ 1
                setB(World.bulbProgress, p)
                if p != 0 { return }
                setLocationByte(index, World.bulbs, 0x10)
                DuneEngine.shared.logger.log(.info, "Ecology: 16 bulbs grown at place \(index)")
            }
            setTroopOccupation(id, TroopJob.irrigation)
        case TroopJob.windTrap:
            // seg000:7711: assembly progress in the water byte until it wraps.
            if locationByte(index, 10) & World.statusWindTrap == 0 {
                setTroopByte(id, 0x15, UInt8(min(100, troopMotivation(id) + 1))) // troop_increase_motivation (6f48)
                // troop_0348a: min(255, 2 x motivation + byte 0x16) x men >> 12, at least 1.
                let v = min(255, 2 * motivationModifier(id) + Int(troopByte(id, 0x16)))
                let men = Int(troopByte(id, 26))
                var gain = (v * men) >> 12
                if gain == 0 && men >= 1 { gain = 1 }
                let water = Int(locationByte(index, World.water)) + gain
                if water <= 0xFF {
                    setLocationByte(index, World.water, UInt8(water))
                    return
                }
                setLocationByte(index, 10, locationByte(index, 10) | World.statusWindTrap)
                setLocationByte(index, 8, locationByte(index, 8) | 8)
                setLocationByte(index, World.water, 5)
                DuneEngine.shared.logger.log(.info, "Ecology: wind trap assembled at place \(index)")
            }
            // troop_clear_occupation_bits_0_and_1 (6ac5): back to irrigation.
            setTroopByte(id, 3, troopByte(id, 3) & 0xFC)
        case TroopJob.irrigation:
            irrigate(id, index)
        default:
            break
        }
    }

    /// seg000:7693. Not viable (6bd7): a sulking troop, no water, no wind
    /// trap, or no bulbs carried.
    private func irrigate(_ id: Int, _ index: Int) {
        let status = locationByte(index, 10)
        if troopByte(id, 3) & TroopJob.stopped != 0 || troopWord(id, 0x12) & 0x30 != 0
            || locationByte(index, World.water) < 1 || status & World.statusWindTrap == 0 || troopByte(id, 25) & 2 == 0 {
            setTroopByte(id, 3, troopByte(id, 3) | TroopJob.stopped)
            return
        }
        setTroopWord(id, 0x10, troopWord(id, 0x10) | 0x100)
        if status & World.statusVegetation == 0 {
            // The first vegetation: no more spice here; a disc of radius 4
            // round the place.
            setLocationByte(index, 10, status | World.statusVegetation)
            setLocationByte(index, World.density, 0)
            setLocationWord(index, World.discLongitude, locationWord(index, 2))
            setLocationByte(index, World.discLatitude, locationByte(index, 4))
            setLocationByte(index, World.discProgress, 0)
            setLocationByte(index, World.discRadius, 4)
            setB(0xFA, 1) // vegetation_started_on_Dune
            DuneEngine.shared.logger.log(.info, "Ecology: vegetation starts at place \(index)")
            spreadVegetation(index)
            return
        }
        // The ecology skill / 4 (at least 1) fills the progress byte; each
        // wrap raises the skill, spends 12 water, widens the disc (up to 12)
        // and moves it 2 north (not past -82).
        let step = max(1, Int(troopByte(id, 0x18)) >> 2)
        let progress = Int(locationByte(index, World.discProgress)) + step
        setLocationByte(index, World.discProgress, UInt8(truncatingIfNeeded: progress))
        if progress <= 0xFF { return }
        raiseSkill(id, skillClass: 2, 1)
        let water = locationByte(index, World.water)
        if water < 12 {
            setLocationByte(index, World.water, 0)
            setTroopByte(id, 3, troopByte(id, 3) | TroopJob.stopped) // callback_troop_make_troop_stop_working (7085)
            setTroopWord(id, 0x10, troopWord(id, 0x10) & ~0x100)
            return
        }
        setLocationByte(index, World.water, water - 12)
        let radius = locationByte(index, World.discRadius)
        if radius < 12 { setLocationByte(index, World.discRadius, radius + 1) }
        let lat = Int(Int8(bitPattern: locationByte(index, World.discLatitude))) - 2
        if lat >= -82 { setLocationByte(index, World.discLatitude, UInt8(bitPattern: Int8(lat))) }
        spreadVegetation(index)
    }

    /// seg000:6515 with the callback at 653a: every cell of the disc not
    /// yet sprouting becomes Atreides land, a quarter of the sand ones
    /// sprout (the rotating mask 0x44 on terrain < 8); a place's cell under
    /// it loses its spice, and a Harkonnen fortress there falls (not the
    /// two palaces).
    func spreadVegetation(_ index: Int) {
        var mask: UInt8 = 0x44
        var fallen: [Int] = []
        let count = locationCount
        forDisc(longitude: locationWord(index, World.discLongitude),
                latitude: Int(Int8(bitPattern: locationByte(index, World.discLatitude))),
                radius: Int(locationByte(index, World.discRadius)), limit: 0x56) { o, c in
            if c & 0x30 == 0x10 { return }
            if c & 0x40 != 0 {
                for i in 0..<count where Int(locationWord(i, 6)) == o {
                    setLocationByte(i, World.density, 0)
                    if !friendlyPlace(i) && i >= 2 {
                        setLocationByte(i, 10, locationByte(i, 10) & 0x7F)
                        fallen.append(i)
                    }
                    break
                }
            }
            var v = (c & 0xCF) | 0x20
            if c & 0x0E < 8 {
                let carry = mask & 0x80 != 0
                mask = (mask << 1) | (carry ? 1 : 0)
                if carry { v = (v & 0xCF) | 0x10 }
            }
            c = v
        }
        for i in fallen { fortressTaken(i) }
    }

    /// location_battle_won_for_fortress (seg000:7443) as the vegetation
    /// reaches it: the land round it turns Atreides, charisma + 4, every
    /// troop's motivation + 1, the fortress is held (status bit 3); its
    /// Harkonnens become free Fremen (up to 8, 075ea) or leave the game.
    /// (ScummVM keeps this apart from battleWon; so does SwiftDune.)
    func fortressTaken(_ index: Int) {
        paintArea(index, stage: 0x20, radius: 5)
        setLocationByte(index, World.discRadius, UInt8(truncatingIfNeeded: (w(World.gameTime) >> 4) &+ 2))
        addCharisma(4)
        for id in 1...World.troopCount where troopByte(id, 3) & 0xA0 == 0 {
            setTroopByte(id, 0x15, UInt8(min(100, troopMotivation(id) + 1)))
        }
        setLocationByte(index, 10, locationByte(index, 10) | World.statusAtreides)
        var freed = 0
        for t in troopsAt(index) {
            let id = t.id
            if troopByte(id, 16) & 0x80 == 0 { continue }
            setTroopByte(id, 16, troopByte(id, 16) & 0x7F)
            setTroopByte(id, 3, 0xA0)
            if freed < 8 {
                // randMasked there is the ds:0 roll masked (rollRandom here).
                let r1 = (rollRandom(0x10000) & 0x0F7F) + 0x1464
                let r2 = (rollRandom(0x10000) & 0x1F1F) + 0x0A0A
                setTroopByte(id, 26, UInt8(truncatingIfNeeded: r1))
                setTroopByte(id, 21, UInt8(truncatingIfNeeded: r1 >> 8))
                setTroopByte(id, 22, UInt8(truncatingIfNeeded: r2))
                setTroopByte(id, 23, UInt8(truncatingIfNeeded: r2 >> 8))
                setTroopByte(id, 25, 0)
            } else {
                setTroopByte(id, 26, 0)
            }
            freed += 1
        }
        DuneEngine.shared.logger.log(.info, "Ecology: the vegetation takes place \(index) from the Harkonnens")
        // accumulate_harkonnen_spice_production (1cda) counts the places
        // still Harkonnen; with one left (their palace) the final attack begins.
        let left = (0..<locationCount).filter { !friendlyPlace($0) }.count
        if left <= 1 {
            setB(World.finalAttack, 1)
            setRawB(0xFF7, rawB(0xFF7) & 0xFD)
            setRawB(0x1007, rawB(0x1007) & 0xFD)
            DuneEngine.shared.logger.log(.info, "Ecology: only the Harkonnen palace is left, the final attack begins")
        }
    }

    /// The new day's ecology walk (seg000:63f0): water behind the wind
    /// traps, then the vegetation's promotion (65b6).
    func ecologyNewDay() {
        // Pass 1: water behind every wind trap grows by 1 + half the
        // sprouting cells round the place, up to 250.
        for i in 0..<locationCount {
            let water = locationByte(i, World.water)
            guard locationByte(i, 10) & World.statusWindTrap != 0, water < 0xFA else { continue }
            let o = Int(locationWord(i, 6))
            var near = 0
            for k in 0..<6 where o + k >= 1 && o + k - 1 < map.count && map[o + k - 1] & 0x30 == 0x10 {
                near += 1
            }
            setLocationByte(i, World.water, UInt8(min(0xFA, Int(water) + 1 + near / 2)))
        }
        // Pass 2: 0x46 steps of the LFSR (taps 0x402); each column visited
        // is walked down the map every 0x7FF bytes, and sprouting cells
        // (0x10) grow into tufts (0x20).
        var state = ecologyLfsr != 0 ? ecologyLfsr : 1
        for _ in 0..<0x46 {
            let carry = state & 1 != 0
            state >>= 1
            if carry { state ^= 0x402 }
            var o = Int(state)
            while o < 0xC5F9 && o < map.count {
                if map[o] & 0x30 == 0x10 { map[o] = (map[o] & 0xCF) | 0x20 }
                o += 0x7FF
            }
        }
        ecologyLfsr = state
    }


    // MARK: Equipment

    /// seg000:7f27: the place's stock (bytes 20-26: harvesters .. bulbs)
    /// less what its troops hold.
    func placeFreeEquipment(_ index: Int) -> [Int] {
        var counts = (0..<7).map { Int(locationByte(index, 20 + $0)) }
        for t in troopsAt(index) {
            let equipment = troopByte(t.id, 25)
            for k in 0..<7 where equipment & (0x80 >> k) != 0 && counts[k] > 0 {
                counts[k] -= 1
            }
        }
        return counts
    }

    /// MODIFY EQUIPMENT: the troop takes one free item of `type` (0
    /// harvester .. 6 bulbs) from its place. False when it has one or none
    /// is free.
    @discardableResult
    func takeEquipment(troop id: Int, type: Int) -> Bool {
        guard troopExists(id), type >= 0 && type < 7, let index = troopPlace(id) else { return false }
        let bit = UInt8(0x80 >> type)
        guard troopByte(id, 25) & bit == 0, placeFreeEquipment(index)[type] > 0 else { return false }
        setTroopByte(id, 25, troopByte(id, 25) | bit)
        return true
    }

    /// MODIFY EQUIPMENT: the troop leaves its item of `type` at its place.
    @discardableResult
    func giveEquipment(troop id: Int, type: Int) -> Bool {
        guard id >= 1 && id <= World.troopCount, type >= 0 && type < 7 else { return false }
        let bit = UInt8(0x80 >> type)
        guard troopByte(id, 25) & bit != 0 else { return false }
        setTroopByte(id, 25, troopByte(id, 25) & ~bit)
        return true
    }
}
