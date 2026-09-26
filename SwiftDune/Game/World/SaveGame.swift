//
//  SaveGame.swift
//  SwiftDune
//
//  Saves in the DOS format: DUNE21S<n>.SAV (floppy) / DUNE37S<n>.SAV (CD).
//  Header: time (u16), 0x02F7 (floppy; low byte 0xF7 = RLE marker), file
//  length - 2 (u16); then an RLE body (marker, count, value):
//    map stage bits, 4 pixels per byte          12,671 bytes
//    an extra block of the executable's own     0xC6 floppy / 0xA2 CD
//    DIALOGUE.HSQ with its said flags           4,464 bytes (floppy)
//    the data segment vars[0 ..< savedSize]     0x126E floppy
//
//  Port of the ScummVM Dune engine's saves.cpp. The stage bits are the
//  live map's (World.map, Ecology.swift): a load puts them back into each
//  cell as (cell & 0xCF) | bits << 4 and marks the places' cells again.
//  Slots load from Documents first (games saved on this device), then from
//  the game folder (the five saves shipped with the floppy release).
//

import Foundation


final class SaveGame {
    static let shared = SaveGame()

    static let mapFlagBytes = 12_671
    static let rleMarker: UInt8 = 0xF7

    private let world = World.shared
    private let story = Story.shared
    private var extra: [UInt8] = []

    private init() {}

    private var extraSize: Int { world.isFloppy ? 0xC6 : 0xA2 }
    /// Floppy saves keep 0x126E bytes of the segment; the CD 13 fewer.
    private var savedSize: Int { 0x1261 + (world.palaceTable - 0x1225) }

    func fileName(_ slot: Int) -> String {
        world.isFloppy ? "DUNE21S\(slot).SAV" : "DUNE37S\(slot).SAV"
    }

    private func documentsURL(_ slot: Int) -> URL {
        DuneEngine.outputDirectory.appendingPathComponent(fileName(slot))
    }

    private func read(_ slot: Int) -> [UInt8]? {
        if let data = try? Data(contentsOf: documentsURL(slot)) {
            return [UInt8](data)
        }
        let name = fileName(slot) as NSString
        if let url = Bundle.main.url(forResource: name.deletingPathExtension, withExtension: name.pathExtension,
                                     subdirectory: "DuneFiles"),
           let data = try? Data(contentsOf: url) {
            return [UInt8](data)
        }
        return nil
    }

    /// Game time stored in a slot's header, nil when the slot is empty.
    func slotTime(_ slot: Int) -> UInt16? {
        guard let packed = read(slot), packed.count >= 6 else { return nil }
        return UInt16(packed[0]) | UInt16(packed[1]) << 8
    }

    static func unpack(_ packed: [UInt8]) -> [UInt8] {
        guard packed.count >= 6 else { return [] }
        let marker = packed[2]
        var body: [UInt8] = []
        var i = 6
        while i < packed.count {
            let b = packed[i]
            i += 1
            if b == marker && i + 1 < packed.count {
                body.append(contentsOf: repeatElement(packed[i + 1], count: Int(packed[i])))
                i += 2
            } else {
                body.append(b)
            }
        }
        return body
    }

    static func pack(_ body: [UInt8]) -> [UInt8] {
        var packed: [UInt8] = []
        var i = 0
        while i < body.count {
            let value = body[i]
            var run = 1
            while i + run < body.count && body[i + run] == value && run < 255 { run += 1 }
            if run > 2 || value == rleMarker {
                packed += [rleMarker, UInt8(run), value]
            } else {
                packed += repeatElement(value, count: run)
            }
            i += run
        }
        return packed
    }

    @discardableResult
    func load(_ slot: Int) -> Bool {
        guard let packed = read(slot) else {
            DuneEngine.shared.logger.log(.warn, "Saves: slot \(slot) is empty")
            return false
        }
        let body = SaveGame.unpack(packed)
        let dialogueSize = story.dialogue.data.count
        let expected = SaveGame.mapFlagBytes + extraSize + dialogueSize + savedSize
        guard body.count >= expected else {
            DuneEngine.shared.logger.log(.error, "Saves: slot \(slot) holds \(body.count) bytes, \(expected) expected")
            return false
        }
        var p = SaveGame.mapFlagBytes
        extra = Array(body[p..<(p + extraSize)]); p += extraSize
        story.dialogue.setData(Array(body[p..<(p + dialogueSize)])); p += dialogueSize
        world.restore(Array(body[p..<(p + savedSize)]))
        // The map's flag bits, four cells to a byte, first cell in the top
        // bits (sub_1B427); restore() has reset the map to MAP.HSQ.
        for i in 0..<SaveGame.mapFlagBytes {
            for k in 0..<4 where 4 * i + k < world.map.count {
                let cell = 4 * i + k
                world.map[cell] = (world.map[cell] & 0xCF) | ((body[i] >> (6 - 2 * k)) & 3) << 4
            }
        }
        world.markPlaceCells()
        story.rebuildNotebook()
        DuneEngine.shared.logger.log(.info, "Saves: slot \(slot) loaded, time \(world.w(World.gameTime)), place \(world.currentLocation) room \(world.room), phase \(String(world.b(World.phase), radix: 16))")
        return true
    }

    @discardableResult
    func save(_ slot: Int) -> Bool {
        var body = [UInt8](repeating: 0, count: SaveGame.mapFlagBytes)
        for i in 0..<SaveGame.mapFlagBytes {
            for k in 0..<4 where 4 * i + k < world.map.count {
                body[i] |= ((world.map[4 * i + k] >> 4) & 3) << (6 - 2 * k)
            }
        }
        body += extra.count == extraSize ? extra : [UInt8](repeating: 0, count: extraSize)
        body += story.dialogue.data
        body += world.vars[0..<savedSize]

        var packed: [UInt8] = [0, 0, SaveGame.rleMarker, world.isFloppy ? 0x02 : 0x00, 0, 0]
        let time = world.w(World.gameTime)
        packed[0] = UInt8(time & 0xFF); packed[1] = UInt8(time >> 8)
        packed += SaveGame.pack(body)
        let length = UInt16(packed.count - 2)
        packed[4] = UInt8(length & 0xFF); packed[5] = UInt8(length >> 8)

        do {
            try Data(packed).write(to: documentsURL(slot))
            DuneEngine.shared.logger.log(.info, "Saves: \(fileName(slot)) written (\(packed.count) bytes)")
            return true
        } catch {
            DuneEngine.shared.logger.log(.error, "Saves: cannot write \(fileName(slot)): \(error.localizedDescription)")
            return false
        }
    }
}
