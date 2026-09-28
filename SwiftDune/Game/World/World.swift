//
//  World.swift
//  SwiftDune
//
//  The game world as the original program keeps it: one copy of the
//  executable's initial data segment (0x1500 bytes, "vars"), read from
//  DUNEPRG.EXE (floppy, LZEXE-packed) or DNCDPRG.EXE (CD). Locations, room
//  tables, characters and troops are records inside it, so saves, dialogue
//  conditions and game rules can all read and write the same bytes.
//
//  Where the knowledge came from: a port of the ScummVM Dune engine's
//  world.cpp / world.h (github.com/AppTesterMC/desert-frost-engine,
//  third_party/scummvm/engines/dune; same authors) and its FINDINGS.md,
//  which cite the OpenRakis DNCDPRG disassembly, madmoose's chani database
//  and dune-rust. Offsets in comments are CD data-segment offsets unless
//  marked "floppy"; `ds(_:)` converts them.
//

import Foundation


// MARK: - LZEXE 0.91

/// Unpacker for LZEXE 0.91 (Fabrice Bellard, 1989), the packer used on the
/// floppy DUNEPRG.EXE. Returns the unpacked program image (no MZ header).
enum Lzexe {
    static func unpack(_ packed: [UInt8]) -> [UInt8]? {
        guard packed.count >= 32, packed[0] == 0x4D, packed[1] == 0x5A,
              Array(packed[28..<32]) == Array("LZ91".utf8) else { return nil }

        func word(_ o: Int) -> Int { Int(packed[o]) | Int(packed[o + 1]) << 8 }

        let loader = (word(8) + word(22)) * 16
        guard loader + 16 <= packed.count else { return nil }
        let packedParagraphs = word(loader + 8)
        guard packedParagraphs * 16 <= loader else { return nil }

        var position = loader - packedParagraphs * 16
        var buffer = 0
        var count = 0
        var ok = true

        func reload() {
            if position + 2 > packed.count { ok = false; buffer = 0 } else { buffer = word(position) }
            position += 2
            count = 16
        }
        // Bits are read lowest first; a new word is loaded after the 16th.
        func bit() -> Int {
            let b = buffer & 1
            buffer >>= 1
            count -= 1
            if count == 0 { reload() }
            return b
        }
        func next() -> Int {
            guard position < packed.count else { ok = false; return 0 }
            defer { position += 1 }
            return Int(packed[position])
        }

        reload()
        var out: [UInt8] = []
        out.reserveCapacity(loader * 2)

        while true {
            guard ok else { return nil }
            if bit() == 1 {
                out.append(UInt8(next()))
                continue
            }
            var length: Int
            let distance: Int
            if bit() == 0 {
                length = bit() << 1
                length |= bit()
                length += 2
                distance = next() - 256
            } else {
                let low = next()
                let high = next()
                distance = (((high & 0xF8) << 5) | low) - 8192
                length = (high & 7) + 2
                if length == 2 {
                    length = next()
                    if length == 0 { break }      // end of the stream
                    if length == 1 { continue }   // segment change
                    length += 1
                }
            }
            guard out.count + distance >= 0 else { return nil }
            for _ in 0..<length {
                out.append(out[out.count + distance])
            }
        }
        return out.isEmpty ? nil : out
    }
}


// MARK: - Records

/// A location (sietch, palace, village, fortress): 28 bytes at 0x100 + 28*i.
struct Location {
    static let tableOffset = 0x100
    static let recordSize = 28

    // Place types (record byte 8).
    static let sietchMax: UInt8 = 0x1F
    static let palace: UInt8 = 0x20
    static let villageMin: UInt8 = 0x21
    static let villageMax: UInt8 = 0x27
    static let fortressMin: UInt8 = 0x28
    static let fortressMax: UInt8 = 0x2F
    static let harkonnenPalace: UInt8 = 0x30

    var firstName: UInt8 = 0
    var lastName: UInt8 = 0
    var longitude: UInt16 = 0
    var latitude: Int16 = 0
    var mapOffset: UInt16 = 0
    var type: UInt8 = 0
    var troop: UInt8 = 0
    /// 0x80 hidden, 0x40 prospected, 0x20 wind trap, 0x10 visited,
    /// 0x08 Atreides, 0x04 saboteurs, 0x02 battle, 0x01 vegetation.
    var status: UInt8 = 0
    var discoverPhase: UInt8 = 0
    var spiceField: UInt8 = 0
    var spiceAmount: UInt8 = 0
    var spiceDensity: UInt8 = 0
    var harvesters: UInt8 = 0
    var ornithopters: UInt8 = 0
    var water: UInt8 = 0

    var isSietch: Bool { type <= Location.sietchMax }
    var hidden: Bool { status & 0x80 != 0 }
    /// Map icon kind: 0 sietch, 1 Atreides palace, 2 village, 3 fortress,
    /// 4 Harkonnen palace (_sub_15E4F_calc_SAL_index).
    var kind: Int {
        type < 0x20 ? 0 : type < 0x21 ? 1 : type < 0x28 ? 2 : type < 0x30 ? 3 : 4
    }
    /// Friendly for travel: below fortress types, or held by the Atreides.
    var friendly: Bool { type < Location.fortressMin || status & 0x08 != 0 }
}


/// One room of a place: `code, up, right, down, left`.
struct RoomRecord {
    var code: UInt8
    /// up, right, down, left.
    var exits: [UInt8]

    /// Room inside the place's .SAL file.
    var salRoom: Int { Int((code &- 1) & 0x0F) }
    /// Index into the release's sprite-sheet slot table.
    var sheetSlot: Int { Int((code &- 1) >> 4) }

    enum Exit: Equatable {
        case none
        case room(Int)
        /// Bit 7 set: a door the story has not opened yet. No arrow.
        case locked(Int)
        /// 252-254: leave the place (the flat map picks a destination).
        case leave
        /// 255: the village's "up" exit, meaning unknown.
        case unknown
    }

    static func decode(_ value: UInt8) -> Exit {
        switch value {
        case 0: return .none
        case 1...127: return .room(Int(value))
        case 252...254: return .leave
        case 255: return .unknown
        default: return .locked(Int(value & 0x7F))
        }
    }
}


/// A character record: 16 bytes at 0xFD8 + 16*i.
struct CharacterRecord {
    var room: UInt8
    var placeType: UInt8
    var locationPlusOne: UInt8
    var index: UInt8
    var flags: UInt8
}


/// A troop record: 27 bytes at 0x8AA + 27*(id-1), ids 1...68.
struct Troop {
    var id: Int
    var next: UInt8
    /// Low 4 bits the job; 0x10 stopped, 0x20 captured, 0x40 moving,
    /// 0x80 not hired.
    var occupation: UInt8
    var flags: UInt8
    var men: UInt8

    var hired: Bool { occupation & 0x80 == 0 }
    var harkonnen: Bool { flags & 0x80 != 0 }
}


// MARK: - World

final class World {
    static let shared = World()

    static let size = 0x1500
    static let characterTable = 0xFD8
    static let characterSize = 16
    static let characterCount = 16
    static let troopTable = 0x8AA
    static let troopSize = 27
    static let troopCount = 68

    // Character numbers (PERS.HSQ frame = 2 * min(number, 15)).
    static let leto = 0, jessica = 1, thufir = 2, duncan = 3, gurney = 4
    static let stilgar = 5, kynes = 6, chani = 7, harah = 8
    static let captain = 12, smuggler = 13, fremen = 14, fremenChief = 15

    // Named variables (CD offsets, see FINDINGS.md).
    static let gameTime = 0x02
    static let roomAndPlace = 0x04   // room, place type, 0x80, location + 1
    static let personsWith = 0x10
    static let charisma = 0x29
    static let phase = 0x2A
    static let markerShift = 0xC7

    /// The data segment. Initially the executable's, later a save's.
    private(set) var vars = [UInt8](repeating: 0, count: World.size)
    private var initialVars: [UInt8] = []
    private(set) var isFloppy = true
    private(set) var loaded = false
    private(set) var palaceTable = 0
    /// An ending the rules reached (COMMAND id of its text), for the game to show.
    var pendingEnding: Int?
    /// Mining's carried remainder under 10 kg (ds:46e1, outside the save).
    var harvestRemainder = 0
    /// rand (seg000:e3cc) and rand_masked (e3b7) states, ds:d826 / ds:d824:
    /// outside the save and seeded from the clock (seg000:00c3), so a
    /// reload rerolls every battle (Battles.swift).
    var rngA: UInt16 = 1
    var rngB: UInt16 = 1
    /// The new day's vegetation walk keeps its shift register in the code
    /// segment (cs:65b4, 1 at start), unsaved (Ecology.swift).
    var ecologyLfsr: UInt16 = 1
    private(set) var pointerTable = 0

    private let logger = DuneEngine.shared.logger

    private static let dataSegmentHead: [UInt8] = [0x00, 0x00, 0x02, 0x00, 0x0A, 0x20, 0x80, 0x01, 0x20, 0x00, 0x00, 0x0A]
    /// The palace room table's first record (room 1, the palace front).
    private static let palaceTableHead: [UInt8] = [76, 2, 0, 253, 0]
    private static let pointerEntries = 0x34

    private init() {
        load()
        seedRandom()
    }


    // MARK: Loading

    private func executable(_ name: String) -> [UInt8]? {
        let base = (name as NSString).deletingPathExtension
        let ext = (name as NSString).pathExtension
        _ = (base, ext)
        guard let path = DuneArchive.path(name), let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { return nil }
        let raw = [UInt8](data)
        if raw.count >= 32 && Array(raw[28..<32]) == Array("LZ91".utf8) {
            return Lzexe.unpack(raw)
        }
        return raw
    }

    private func load() {
        for (name, floppy) in [("DUNEPRG.EXE", true), ("DNCDPRG.EXE", false)] {
            guard let image = executable(name),
                  let start = find(World.dataSegmentHead, in: image, from: 0) else { continue }
            let available = min(World.size, image.count - start)
            vars = [UInt8](repeating: 0, count: World.size)
            vars.replaceSubrange(0..<available, with: image[start..<(start + available)])
            isFloppy = floppy
            findSceneScripts(image)
            loaded = findTables()
            initialVars = vars
            logger.log(.info, "World: initial data from \(name) at \(start), tables \(loaded ? "found" : "missing")")
            return
        }
        logger.log(.error, "World: no DUNEPRG.EXE / DNCDPRG.EXE with the initial data segment")
    }

    // MARK: Scripted scenes

    private static var code: [UInt8] = []
    private static var scriptBase = -1
    private static var scriptDelta = 0

    /// The scripted scenes (the " Continue..." sequences, seg000:1707) live
    /// in the code. The phase-scene handler loads their offsets as
    /// immediates (mov bl,[2a]; mov ax,X; cmp bl,14h); the first, 0x12F8
    /// on the CD, is the prospector's lesson (bytes 0E 10 FF), which fixes
    /// where the code starts in the image (ScummVM findSceneScripts).
    private func findSceneScripts(_ image: [UInt8]) {
        World.scriptBase = -1
        let head: [UInt8] = [0x8A, 0x1E, 0x2A, 0x00, 0xB8]
        var p = 0
        while p + 32 <= image.count {
            if image[p] == head[0] && Array(image[p..<(p + 5)]) == head && image[p + 7] == 0x80
                && image[p + 8] == 0xFB && image[p + 9] == 0x14 {
                let x = Int(image[p + 5]) | Int(image[p + 6]) << 8
                let headerSize = image.count > 0x20 && image[0] == 0x4D && image[1] == 0x5A
                    ? (Int(image[8]) | Int(image[9]) << 8) * 16 : 0
                for base in [0, headerSize] {
                    let at = base + x
                    if at + 3 <= image.count && image[at] == 0x0E && image[at + 1] == 0x10 && image[at + 2] == 0xFF {
                        World.scriptBase = base
                        World.scriptDelta = x - 0x12F8
                        World.code = image
                        DuneEngine.shared.logger.log(.info, "World: scripted scenes at code offset delta \(x - 0x12F8)")
                        return
                    }
                }
            }
            p += 1
        }
        DuneEngine.shared.logger.log(.warn, "World: the scripted scenes were not found in the executable")
    }

    /// Up to 96 bytes of the scene script at CD code offset `cdOffset`.
    func sceneScript(_ cdOffset: UInt16) -> [UInt8] {
        guard World.scriptBase >= 0 else { return [] }
        let at = World.scriptBase + Int(cdOffset) + World.scriptDelta
        guard at >= 0 && at < World.code.count else { return [] }
        return Array(World.code[at..<min(at + 96, World.code.count)])
    }


    private func find(_ needle: [UInt8], in haystack: [UInt8], from: Int) -> Int? {
        guard haystack.count >= needle.count else { return nil }
        var p = from
        while p + needle.count <= haystack.count {
            if haystack[p] == needle[0] && Array(haystack[p..<(p + needle.count)]) == needle {
                return p
            }
            p += 1
        }
        return nil
    }

    private func findTables() -> Bool {
        guard let palace = find(World.palaceTableHead, in: vars, from: 0x1000) else {
            logger.log(.error, "World: palace room table not found")
            return false
        }
        palaceTable = palace
        var p = palace + 60
        while p + 2 <= World.size {
            if w(raw: p) == palace && p >= 0x40 {
                pointerTable = p - 2 * Int(Location.palace)
                return true
            }
            p += 1
        }
        logger.log(.error, "World: room pointer table not found")
        return false
    }

    /// ds:11EB (CD): 16 sentence ids read by the text codes 0x81-0x8F.
    var nameTable: Int { 0x11EB + (palaceTable - 0x1225) }

    /// A save's segment prefix; the rest keeps the executable's values.
    func restore(_ saved: [UInt8]) {
        reset()
        vars.replaceSubrange(0..<min(saved.count, World.size), with: saved.prefix(World.size))
    }

    /// Back to the executable's state (new game).
    func reset() {
        if !initialVars.isEmpty {
            vars = initialVars
            harvestRemainder = 0
            prepareNewGame()
        }
    }


    // MARK: Byte access

    /// CD data-segment offset -> this release's offset. The floppy segment
    /// is 2 bytes shorter in 0x1158...0x11BF and 13 bytes longer after it.
    func ds(_ cdOffset: Int) -> Int {
        guard isFloppy else { return cdOffset }
        if cdOffset < 0x1158 { return cdOffset }
        if cdOffset < 0x11C0 { return cdOffset - 2 }
        return cdOffset + 13
    }

    func b(_ cdOffset: Int) -> UInt8 { vars[ds(cdOffset)] }
    func setB(_ cdOffset: Int, _ value: UInt8) { vars[ds(cdOffset)] = value }
    func w(_ cdOffset: Int) -> UInt16 { w(raw: ds(cdOffset)) }
    func setW(_ cdOffset: Int, _ value: UInt16) {
        let o = ds(cdOffset)
        vars[o] = UInt8(value & 0xFF)
        vars[o + 1] = UInt8(value >> 8)
    }
    func rawB(_ o: Int) -> UInt8 { vars[o] }
    /// Writes a byte at a raw segment offset (records: troops, places).
    func setRawB(_ o: Int, _ value: UInt8) { vars[o] = value }
    func rawW(_ o: Int) -> UInt16 { w(raw: o) }
    private func w(raw o: Int) -> Int { Int(vars[o]) | Int(vars[o + 1]) << 8 }
    private func w(raw o: Int) -> UInt16 { UInt16(vars[o]) | UInt16(vars[o + 1]) << 8 }


    // MARK: Locations

    var locationCount: Int {
        var count = 0
        while count < 80 {
            let o = Location.tableOffset + count * Location.recordSize
            if o + 2 > World.size || (vars[o] == 0xFF && vars[o + 1] == 0xFF) { break }
            count += 1
        }
        return count
    }

    func location(_ index: Int) -> Location {
        var l = Location()
        let o = Location.tableOffset + index * Location.recordSize
        guard index >= 0, o + Location.recordSize <= World.size else { return l }
        l.firstName = vars[o]
        l.lastName = vars[o + 1]
        l.longitude = w(raw: o + 2)
        l.latitude = Int16(bitPattern: w(raw: o + 4))
        l.mapOffset = w(raw: o + 6)
        l.type = vars[o + 8]
        l.troop = vars[o + 9]
        l.status = vars[o + 10]
        l.discoverPhase = vars[o + 11]
        l.spiceField = vars[o + 16]
        l.spiceAmount = vars[o + 17]
        l.spiceDensity = vars[o + 18]
        l.harvesters = vars[o + 20]
        l.ornithopters = vars[o + 21]
        l.water = vars[o + 27]
        return l
    }

    /// "Carthag-Tuek": first name COMMAND `first - 1`, second COMMAND
    /// `11 + last` (the palaces give "Palace (Atreides)"-style pairs).
    func locationName(_ index: Int, _ command: (Int) -> String) -> String {
        let l = location(index)
        guard l.firstName != 0 else { return "" }
        return command(Int(l.firstName) - 1) + "-" + command(11 + Int(l.lastName))
    }

    var currentLocation: Int {
        let plusOne = b(7)
        return plusOne > 0 ? Int(plusOne) - 1 : 0
    }

    var placeType: UInt8 { b(World.roomAndPlace + 1) }
    var room: Int { Int(b(World.roomAndPlace)) }

    /// Moves Paul to `room` of `locationIndex` (ds:4...ds:0B).
    func setPosition(location locationIndex: Int, room: Int) {
        let l = location(locationIndex)
        setB(World.roomAndPlace, UInt8(room))
        setB(World.roomAndPlace + 1, l.type)
        setB(7, UInt8(locationIndex + 1))
        setB(8, l.type)
        setB(0x0B, UInt8(room))
        // Name-table words 1 and 2 feed text codes 0x81/0x82
        // ("Welcome to \x81-\x82"): 1-based COMMAND ids.
        let names = nameTable
        vars[names + 2] = l.firstName; vars[names + 3] = 0
        vars[names + 4] = 12 &+ l.lastName; vars[names + 5] = 0
    }

    func setRoom(_ room: Int) {
        setB(World.roomAndPlace, UInt8(room))
        setB(0x0B, UInt8(room))
    }


    // MARK: Rooms

    /// The room table of a place type (pointer table entry `placeType`).
    /// Tables sit back to back: the next higher pointer ends one.
    func roomTable(_ placeType: UInt8) -> [RoomRecord] {
        guard loaded, Int(placeType) < World.pointerEntries else { return [] }
        let start: Int = w(raw: pointerTable + 2 * Int(placeType))
        var end = World.size
        for i in 0..<World.pointerEntries {
            let other: Int = w(raw: pointerTable + 2 * i)
            if other > start && other < end { end = other }
        }
        if placeType == Location.palace {
            end = min(end, start + 12 * 5)
        } else if placeType == Location.harkonnenPalace {
            // Only two rooms; the bytes after them are not room data.
            end = min(end, start + 2 * 5)
        }
        var rooms: [RoomRecord] = []
        var p = start
        while p + 5 <= end && p + 5 <= World.size {
            if vars[p] == 0xFF { break }
            rooms.append(RoomRecord(code: vars[p], exits: Array(vars[(p + 1)...(p + 4)])))
            p += 5
        }
        return rooms
    }

    /// Room `number` (1-based) of the current place.
    func currentRoomRecord() -> RoomRecord? {
        let rooms = roomTable(placeType)
        guard room >= 1 && room <= rooms.count else { return nil }
        return rooms[room - 1]
    }

    /// A story callback opens a door by clearing bit 7 of its exit byte.
    /// `direction`: 0 up, 1 right, 2 down, 3 left.
    func openPalaceDoor(room: Int, direction: Int) {
        guard loaded else { return }
        vars[palaceTable + 5 * (room - 1) + 1 + direction] &= 0x7F
    }

    /// The CD's approach clip for a kind of place (RESOURCE_LIST_HNM 6-10).
    static func arrivalVideo(_ placeType: UInt8) -> String {
        if placeType <= Location.sietchMax { return "SIET.HNM" }
        if placeType <= Location.villageMax { return "PALACE.HNM" }
        return "FORT.HNM"
    }

    static func salFile(_ placeType: UInt8) -> String {
        if placeType <= Location.sietchMax { return "SIET.SAL" }
        if placeType == Location.palace { return "PALACE.SAL" }
        if placeType <= Location.villageMax { return "VILG.SAL" }
        return "HARK.SAL"
    }

    /// The executable's sprite-sheet list from resource 0x13. The releases
    /// differ where the CD replaced the exteriors by videos.
    private static let floppySheets = [
        "POR.HSQ", "PROUGE.HSQ", "COMM.HSQ", "EQUI.HSQ", "BALCON.HSQ", "CORR.HSQ", "SIET0.HSQ", "SIET1.HSQ",
        "VILG.HSQ", "FORT.HSQ", "BUNK.HSQ", "FINAL.HSQ", "SERRE.HSQ", "BOTA.HSQ", "PALPLAN.HSQ", "SUN.HSQ"
    ]
    private static let cdSheets = [
        "GENERIC.HSQ", "PROUGE.HSQ", "COMM.HSQ", "EQUI.HSQ", "BALCON.HSQ", "CORR.HSQ", "POR.HSQ", "SIET1.HSQ",
        "XPLAIN9.HSQ", "", "BUNK.HSQ", "FINAL.HSQ", "SERRE.HSQ", "BOTA.HSQ", "PALPLAN.HSQ", "SUN.HSQ"
    ]

    func sheet(for record: RoomRecord) -> String {
        (isFloppy ? World.floppySheets : World.cdSheets)[record.sheetSlot]
    }

    /// Outdoors: palace SAL rooms 10/11, or sheet slots 6/8/9 elsewhere
    /// (SIET0, VILG, FORT).
    func isOutdoors(_ record: RoomRecord, placeType: UInt8) -> Bool {
        if placeType == Location.palace { return record.salRoom == 10 || record.salRoom == 11 }
        // The floppy's exterior sheets SIET0, VILG, FORT (slots 6, 8, 9);
        // the CD's GENERIC (slot 0), whose backdrop is the arrival clip.
        return isFloppy ? [6, 8, 9].contains(record.sheetSlot) : record.sheetSlot == 0
    }


    // MARK: Characters and troops

    func character(_ index: Int) -> CharacterRecord {
        let o = World.characterTable + index * World.characterSize
        return CharacterRecord(room: vars[o], placeType: vars[o + 1], locationPlusOne: vars[o + 3],
                               index: vars[o + 14], flags: vars[o + 15])
    }

    /// The record's first two words equal ds:4 and ds:6. A location of 0xFF
    /// means away (Thufir and Duncan at the start).
    func characterInRoom(_ index: Int) -> Bool {
        let o = World.characterTable + index * World.characterSize
        return vars[o] == b(4) && vars[o + 1] == b(5) && vars[o + 2] == b(6) && vars[o + 3] == b(7)
    }

    func moveCharacter(_ index: Int, room: Int, location locationIndex: Int?) {
        let o = World.characterTable + index * World.characterSize
        if let locationIndex = locationIndex {
            vars[o] = UInt8(room)
            vars[o + 1] = location(locationIndex).type
            vars[o + 2] = 0x80
            vars[o + 3] = UInt8(locationIndex + 1)
        } else {
            vars[o + 3] = 0xFF
        }
    }

    func troop(_ id: Int) -> Troop {
        let o = World.troopTable + World.troopSize * (id - 1)
        return Troop(id: id, next: vars[o + 1], occupation: vars[o + 3], flags: vars[o + 0x10], men: vars[o + 0x1A])
    }

    /// The troops stationed at a location: its first troop, then the chain.
    func troopsAt(_ locationIndex: Int) -> [Troop] {
        var ids: [Troop] = []
        var id = Int(location(locationIndex).troop)
        while id >= 1 && id <= World.troopCount && ids.count < World.troopCount {
            let t = troop(id)
            ids.append(t)
            id = Int(t.next)
        }
        return ids
    }

    /// Who is in the current room, in ascending character order.
    func peopleInRoom() -> [Int] {
        let with = w(World.personsWith)
        var people: [Int] = []
        for c in 0..<World.characterCount where c != World.fremen && c != World.fremenChief {
            if characterInRoom(c) || (with >> c) & 1 == 1 {
                people.append(c)
            }
        }
        // At a sietch the Fremen troops stand in room 2: the unhired ones as
        // character 14, each hired troop's chief as 15, 16, ...
        if placeType <= Location.sietchMax && room == 2 {
            let troops = troopsAt(currentLocation).filter { !$0.harkonnen }
            if troops.contains(where: { !$0.hired }) {
                people.append(World.fremen)
            }
            for k in 0..<troops.filter({ $0.hired }).count {
                people.append(World.fremenChief + k)
            }
        }
        // The smuggler stands in every room of a type-0x21 village.
        if placeType == Location.villageMin && !people.contains(World.smuggler) {
            people.append(World.smuggler)
        }
        return people
    }

    /// Places the people on the room's markers (sal_read_position_markers):
    /// each takes slot (number + ds:C7) mod markers, or the first free one;
    /// marker j shows slots[markers - 1 - j]. Returns marker -> character.
    func markerAssignment(people: [Int], markers: Int) -> [Int: Int] {
        guard markers > 0 else { return [:] }
        var slots = [Int?](repeating: nil, count: markers)
        let shift = Int(b(World.markerShift))
        for person in people {
            var slot = (person + shift) % markers
            if slots[slot] != nil {
                guard let free = slots.firstIndex(where: { $0 == nil }) else { break }
                slot = free
            }
            slots[slot] = person
        }
        var result: [Int: Int] = [:]
        for j in 0..<markers {
            if let person = slots[markers - 1 - j] {
                result[j] = person
            }
        }
        return result
    }

    /// PERS.HSQ frame of a character standing in a room.
    static func persFrame(_ character: Int) -> UInt16 {
        UInt16(2 * min(character, 15))
    }


    // MARK: Story phase

    /// The scripted scene for dialogue event 3, by phase (seg000:a1f7).
    var phaseSceneScript: UInt16 {
        let p = b(World.phase)
        return p < 0x14 ? 0x12F8 : p < 0x18 ? 0x134F : p < 0x30 ? 0x1370 : 0x12DB
    }

    /// Jessica's training (dialogue event 8): the contact range grows.
    @discardableResult
    func raiseContactRange() -> Int {
        var range = w(0x1176)
        if b(0x0A) & 2 != 0 {
            addCharisma(0x28)
            range = 0xFFCE &+ 0x14
        } else if range == 1 {
            addCharisma(10)
            range = 10 + 0x14
        } else {
            range &+= 0x14
        }
        setW(0x1176, range)
        setB(0xD5, range >= 100 ? 0 : UInt8(0x80 - Int(range & 0xFF) / 6))
        return Int(range)
    }

    func setCharacterByte(_ index: Int, _ byte: Int, _ value: UInt8) {
        vars[characterOffset(index) + byte] = value
    }

    private func characterOffset(_ index: Int) -> Int { World.characterTable + index * World.characterSize }

    private func setCharacterWords(_ index: Int, _ word0: UInt16, _ word1: UInt16) {
        let o = characterOffset(index)
        vars[o] = UInt8(word0 & 0xFF); vars[o + 1] = UInt8(word0 >> 8)
        vars[o + 2] = UInt8(word1 & 0xFF); vars[o + 3] = UInt8(word1 >> 8)
    }

    /// Byte 21: the ornithopters parked at a place.
    func adjustOrnithopters(_ index: Int, _ delta: Int) {
        let o = Location.tableOffset + index * Location.recordSize + 21
        guard o < World.size else { return }
        vars[o] = UInt8(min(255, max(0, Int(vars[o]) + delta)))
    }

    /// Discovering a place: not hidden, byte 11 = 0, and one more known
    /// sietch (ds:27) the first time.
    func discover(_ index: Int) {
        let o = Location.tableOffset + index * Location.recordSize
        guard index < locationCount else { return }
        if vars[o + 10] & 0x80 != 0 && vars[o + 8] <= Location.sietchMax {
            setB(0x27, b(0x27) &+ 1)
        }
        vars[o + 10] &= 0x7F
        vars[o + 11] = 0
    }

    /// Clears the location's "hidden" bit so it shows on the map.
    func reveal(_ places: [Int]) {
        for p in places where p < locationCount {
            vars[Location.tableOffset + p * Location.recordSize + 10] &= 0x7F
        }
    }

    func addCharisma(_ amount: Int) {
        setB(World.charisma, UInt8(min(200, Int(b(World.charisma)) + amount)))
    }

    /// Port of ScummVM World::phaseCallback (state changes only). Returns
    /// the scripted scene / vision it asks for (CD code offsets).
    func phaseCallback(_ phase: UInt8) -> (cutscene: UInt16, vision: UInt16) {
        var cutscene: UInt16 = 0
        var vision: UInt16 = 0
        func v(_ cd: Int) -> Int { ds(cd) }
        let leto = World.leto, jessica = World.jessica, thufir = World.thufir, gurney = World.gurney
        let kynes = World.kynes, chani = World.chani, harah = World.harah

        switch phase {
        case 0x04:
            vars[v(0x122A)] &-= 1
            reveal([10, 17])
        case 0x08: // the passage from room 2 to room 12 opens
            vars[v(0x122E)] &= 0x7F
        case 0x0C: // the COMM room's doors; the gathering scene
            vars[v(0x124A)] &= 0x7F
            vars[v(0x1247)] &= 0x7F
            setW(0x121D, 0xFFFF)
            cutscene = 0x1321
        case 0x10:
            vars[characterOffset(leto)] = 5
            vars[characterOffset(jessica)] = 9
        case 0x14:
            vars[characterOffset(leto)] = 0x0A
            reveal([21, 22, 23])
        case 0x1C:
            vars[v(0x1245)] &= 0x7F
            setW(0x1217, 0xFFFF)
        case 0x20: // Thufir comes to the palace
            vars[characterOffset(thufir) + 3] = 1
            reveal([64])
        case 0x28:
            reveal([64])
        case 0x2C: // Stilgar met
            setW(0x1154, w(World.gameTime))
            setCharacterWords(gurney, 0x2006, 0x0180)
            setCharacterWords(thufir, 0x2008, 0x0180)
            vars[characterOffset(jessica)] = 0x0A
            vars[characterOffset(jessica) + 2] = 0x80; vars[characterOffset(jessica) + 3] = 0x01
            setW(0x1201, 0x0109)
            addCharisma(0x14)
            setB(0x0A, b(0x0A) | 0x10)
            reveal([45, 44, 46, 48, 49])
        case 0x30:
            vision = 4
        case 0x34:
            if vars[characterOffset(jessica)] != 8 {
                vars[characterOffset(jessica)] = 0x0A
                vars[characterOffset(jessica) + 2] = 0x80; vars[characterOffset(jessica) + 3] = 0x01
            }
        case 0x38: // the Duke leaves on his expedition
            vars[characterOffset(leto) + 3] = 0xFF
        case 0x40:
            vars[characterOffset(harah) + 15] |= 2
        case 0x44:
            reveal([26])
        case 0x48: // Chani met
            addCharisma(0x0A)
            cutscene = 0x1313
            vars[characterOffset(chani) + 15] = (vars[characterOffset(chani) + 15] | 0x10) & ~2
            vars[v(0x1178)] = b(0x28) &+ 2
            reveal([27, 28, 25, 69])
        case 0x4C: // the Duke is killed
            vars[v(0x1141)] &+= 1
            vars[characterOffset(jessica)] = 2
            vars[characterOffset(jessica) + 2] = 0x80; vars[characterOffset(jessica) + 3] = 0x01
            vision = 0x105
        case 0x50: // after riding a worm
            setB(0x0A, b(0x0A) | 0x40)
            addCharisma(0x28)
            vars[characterOffset(jessica)] = 9
        case 0x54: // the greenhouse door
            vars[v(0x1259)] &= 0x7F
            setW(0x1211, 0xFFFF)
        case 0x58: // Liet Kynes met
            setB(0x0A, b(0x0A) | 0x20)
            cutscene = 0x12FB
            reveal([63, 60, 61, 67, 65])
        case 0x5C:
            vars[characterOffset(kynes)] = 5
            vars[v(0x11D0)] &+= 0x0C
            setW(0x1156, (w(World.gameTime) >> 4) &+ 3)
            vars[v(0x1141)] &+= 1
        case 0x60: // Chani is taken to the Harkonnen palace
            setB(0xFF, 0)
            let o = characterOffset(chani)
            vars[o] = 2; vars[o + 1] = location(1).type; vars[o + 2] = 0x80; vars[o + 3] = 2
        default:
            break
        }
        logger.log(.info, "World: phase \(String(phase, radix: 16)) callback")
        return (cutscene, vision)
    }


    // MARK: The live map

    /// MAP.HSQ with the stage bits the game changes (ecology, battles,
    /// saves) and bit 6 set on every place's cell: 0x10 vegetation, 0x20
    /// Atreides, 0x30 Harkonnen area. Ecology.swift changes it.
    lazy var map: [UInt8] = freshMap()

    /// TABLAT.BIN: 8 bytes per latitude row 0...98 (big-endian offset and
    /// half-length).
    private(set) lazy var tablat: [UInt8] = Resource("TABLAT.BIN", uncompressed: true).unpackedData

    private(set) lazy var mapRenderer: MapRenderer = {
        MapRenderer(map: { [unowned self] in self.map }, tablat: tablat)
    }()

    /// Distance in map cells, as travel counts it:
    /// max(|dlng| * cells(lat0) / 65536, |dlat|).
    func cellDistance(fromLatitude lat0: Int, longitude lng0: UInt16, toLatitude lat1: Int, longitude lng1: UInt16) -> Int {
        let cells = mapRenderer.rowLength(lat0 + 98)
        let dlng = abs(Int(Int16(bitPattern: lng1 &- lng0)))
        return max(dlng * cells / 65536, abs(lat1 - lat0))
    }


    // MARK: Visions

    static let visionQueue = 0x1190     // count byte, then 10 x (id word, place word)
    static let visionType = 0xEA
    static let paulEvents = 0x0A

    var visionCount: Int { min(Int(b(World.visionQueue)), 10) }

    func vision(_ index: Int) -> (id: UInt16, location: UInt16) {
        (w(World.visionQueue + 1 + 4 * index), w(World.visionQueue + 3 + 4 * index))
    }

    /// seg000:29f0: nothing is queued before Paul's first vision.
    func queueVision(_ id: UInt16, location: UInt16 = 0) {
        guard b(World.paulEvents) & 1 != 0 else { return }
        for i in 0..<visionCount where vision(i) == (id, location) { return }
        if visionCount >= 10 { dequeueVision() }
        let count = visionCount
        setW(World.visionQueue + 1 + 4 * count, id)
        setW(World.visionQueue + 3 + 4 * count, location)
        setB(World.visionQueue, UInt8(count + 1))
        DuneEngine.shared.logger.log(.info, "Vision: queued \(String(id, radix: 16))")
    }

    func dequeueVision() {
        let count = visionCount
        guard count > 0 else { return }
        for i in 0..<9 {
            setW(World.visionQueue + 1 + 4 * i, w(World.visionQueue + 5 + 4 * i))
            setW(World.visionQueue + 3 + 4 * i, w(World.visionQueue + 7 + 4 * i))
        }
        setW(World.visionQueue + 37, 0)
        setW(World.visionQueue + 39, 0)
        setB(World.visionQueue, UInt8(count - 1))
    }

    /// seg000:2a51: a message delivered in person drops the sender's others.
    func purgeVisions(sender: UInt8, location: UInt16) {
        var kept: [(UInt16, UInt16)] = []
        for i in 0..<visionCount {
            let v = vision(i)
            if UInt8(v.id >> 8) == sender && (sender != 0x0F || v.location == location) { continue }
            kept.append(v)
        }
        for i in 0..<10 {
            setW(World.visionQueue + 1 + 4 * i, i < kept.count ? kept[i].0 : 0)
            setW(World.visionQueue + 3 + 4 * i, i < kept.count ? kept[i].1 : 0)
        }
        setB(World.visionQueue, UInt8(kept.count))
    }

    /// sub_11071: phase 0x15; Leto sets off, Gurney's record moves, ds:D5 =
    /// 0xFF; Paul has had his vision; vision message 1 is queued. (The
    /// Emperor's shipments start here too; they are not ported yet.)
    func firstVision() {
        setB(0xFF, 0)
        setB(World.phase, 0x15)
        vars[0xFDB] = 1
        vars[0x1018] = 0x0B; vars[0x1019] = 0x20
        vars[0x101A] = 0x80; vars[0x101B] = 0x01
        vars[0xFE8] = 0x0A
        setB(0xD5, 0xFF)
        setB(World.paulEvents, b(World.paulEvents) | 1)
        addSighting(armShipments())
        queueVision(1)
        DuneEngine.shared.logger.log(.info, "Story: Paul's first vision (phase 0x15)")
    }


    // MARK: Companions and rooms

    /// The record now stands where Paul is (STAY HERE, sent home).
    func settleCharacter(_ index: Int) {
        let o = characterOffset(index)
        vars[o] = b(4); vars[o + 1] = b(5); vars[o + 2] = b(6); vars[o + 3] = b(7)
    }

    /// Two companion slots; a third companion sends the first home.
    /// Returns the character sent home, if any.
    func addCompanion(_ index: Int) -> Int? {
        let id = vars[characterOffset(index) + 14]
        let a = ds(0x1152), bb = ds(0x1153)
        if vars[a] == id || vars[bb] == id { return nil }
        if vars[a] == 0xFF { vars[a] = id; return nil }
        if vars[bb] == 0xFF { vars[bb] = id; return nil }
        let dismissed = Int(vars[a])
        vars[a] = vars[bb]
        vars[bb] = id
        return dismissed
    }

    func removeCompanion(_ index: Int) {
        let id = vars[characterOffset(index) + 14]
        let a = ds(0x1152), bb = ds(0x1153)
        if vars[bb] == id {
            vars[bb] = 0xFF
        } else if vars[a] == id {
            vars[a] = vars[bb]
            vars[bb] = 0xFF
        }
    }

    /// Entering a room marks the place visited (status 0x10); a sietch
    /// counts in ds:25; ds:26 = 0xFF on the first visit.
    func markVisited() {
        let o = Location.tableOffset + currentLocation * Location.recordSize + 10
        guard o < World.size else { return }
        if vars[o] & 0x10 == 0 {
            vars[o] |= 0x10
            setB(0x26, 0xFF)
            if placeType <= Location.sietchMax { setB(0x25, b(0x25) &+ 1) }
        }
    }


    // MARK: Clock

    /// Day shown on the panel: ((t + 3) >> 4) % 365 + 1.
    var day: Int { Int(((UInt32(w(World.gameTime)) + 3) >> 4) % 365) + 1 }
    /// 0...15 within the day.
    var hour: Int { Int(w(World.gameTime) & 0x0F) }
}
