//
//  GameText.swift
//  SwiftDune
//
//  Game text with the original's codes expanded: nested sentences (0x80 +
//  big-endian id), names from the name table (0x81-0x8F), numbers from the
//  data segment (0x90-0x9F; 0x92 reads a word), layout codes (0xD0-0xEF)
//  skipped, 0xFE page breaks kept as "\u{FE}". Sentence ids are 1-based;
//  bit 11 of (id - 1) picks the phrase file (PHRASEx1 for the first five
//  characters' lines, PHRASEx2 from DIALOGUE offset 0x920 on), otherwise
//  COMMANDx.
//
//  Port of ScummVM's SentenceBank::text/expand (engines/dune/text.cpp).
//

import Foundation


final class GameText {
    static let shared = GameText()
    static let pageBreak: Swift.Character = "\u{FE}"
    static let phraseFlag: UInt16 = 0x800

    private let commands = Sentence("COMMAND1.HSQ")
    private let phrases = [Sentence("PHRASE11.HSQ"), Sentence("PHRASE12.HSQ")]

    private init() {}

    /// The game's code names COMMAND entries by their floppy number. The
    /// CD's COMMAND1 inserts entries in several places, so its numbers
    /// differ irregularly: this table (floppy id -> CD id, -1 when the CD
    /// has none) aligns the two files entry by entry (generated from the
    /// floppy COMMAND1.HSQ and the CD DUNE.DAT's COMMAND1.HSQ).
    private static let cdCommandIds: [Int] = [
        0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19,
        20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39,
        40, 41, 42, 43, 44, 45, 46, 57, 58, 59, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69,
        70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83, 84, 85, 86, 87, 88, 89,
        90, 91, 92, 93, 94, 95, 96, 97, 98, 99, 100, 101, 102, 103, 104, 105, 106, 107, 108, 109,
        110, 111, 112, 113, 114, 115, 116, 117, 118, 119, 120, 121, 122, 123, 124, 125, 126, 127, 128, 129,
        130, 131, 132, 133, 134, 135, 136, 137, 138, 139, 140, 141, 142, 143, 144, 145, 146, 147, 148, 149,
        150, 151, 152, 153, 154, 155, 156, 159, 160, 161, 162, 163, 164, 165, 166, 167, 168, 169, 170, 171,
        172, 173, 174, 175, 176, 177, 178, 179, 180, 181, 182, 183, 184, 185, 186, 187, 188, 189, 190, 191,
        192, 193, 194, 195, 196, 197, 198, 199, 200, 201, 202, 203, 204, 205, 206, 207, 208, 209, 210, 211,
        212, 213, 214, 215, 216, 217, 218, 219, 220, 221, 222, 223, 224, 225, 226, 227, 228, 229, 230, 231,
        232, 233, 234, 235, 236, 237, 238, 239, 240, 241, 242, 243, 244, 245, 246, 247, 248, 249, 250, 251,
        252, 253, 254, 255, 256, 257, 258, -1, 259, 260, 261, 263, 264, 265, 266, 267, 268, 269, 270, 271,
        272, 273, 274, 275, 276, 277, 278, 279, 280, 281, 282, 283, 284, 285, 286, 287, 288, 289, 290, 291,
        292, 293, 294, 295, 296, 297, 298, 299, 300, 301, 302, 303, 304, 305, 306, 307, 308, 309, 310, 311,
        312, 313, 314, 315, 316, 317, 318, 319, 320, 321, 322, 323, 324, 325, 326, 327, 328, 329, 330
    ]

    private let isCD = DuneArchive.isCD

    /// Floppy id -> this release's COMMAND index.
    func commandIndex(_ floppyId: Int) -> Int {
        guard isCD else { return floppyId }
        guard floppyId >= 0 && floppyId < GameText.cdCommandIds.count else { return floppyId }
        let mapped = GameText.cdCommandIds[floppyId]
        return mapped >= 0 ? mapped : floppyId
    }

    private lazy var floppyIdByIndex: [Int: Int] = {
        var inverse: [Int: Int] = [:]
        for (floppy, cd) in GameText.cdCommandIds.enumerated() where cd >= 0 { inverse[cd] = floppy }
        return inverse
    }()

    /// Text of a COMMAND entry (0-based index), printable characters only.
    /// COMMAND text by floppy id (translated on the CD).
    func command(_ floppyId: Int) -> String {
        let index = commandIndex(floppyId)
        return String(bytes: commands.rawBytes(at: UInt16(index)).filter { $0 >= 0x20 && $0 < 0x80 }, encoding: .isoLatin1) ?? ""
    }

    private lazy var commandTexts: [String] = (0..<Int(commands.sentenceCount())).map {
        String(bytes: commands.rawBytes(at: UInt16($0)).filter { $0 >= 0x20 && $0 < 0x80 }, encoding: .isoLatin1) ?? ""
    }

    /// The COMMAND index whose text starts with `text` (the numbering
    /// differs between releases, so rows are looked up by text).
    func findCommand(_ text: String) -> Int? {
        // Leading spaces differ between releases ("  Cancel", "Done").
        let wanted = text.trimmingCharacters(in: .whitespaces)
        guard let index = commandTexts.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces).hasPrefix(wanted) }) else { return nil }
        // Returned as a floppy id, like every id the code uses.
        return isCD ? (floppyIdByIndex[index] ?? index) : index
    }

    /// A phrase by 0-based index in PHRASEx1/PHRASEx2, codes expanded.
    func phrase(_ index: Int, secondFile: Bool = false) -> String {
        var out = ""
        expand(phrases[secondFile ? 1 : 0].rawBytes(at: UInt16(index)), secondFile, &out, 0)
        return out
    }

    /// A 1-based sentence id as stored in DIALOGUE/CONDIT and the name table.
    func text(id: UInt16, secondFile: Bool = false) -> String {
        var out = ""
        expand(raw(id, secondFile), secondFile, &out, 0)
        return out
    }

    private func raw(_ id: UInt16, _ secondFile: Bool) -> [UInt8] {
        guard id != 0 else { return [] }
        let index = (id &- 1) & 0x7FF
        if (id &- 1) & GameText.phraseFlag != 0 {
            return phrases[secondFile ? 1 : 0].rawBytes(at: index)
        }
        return commands.rawBytes(at: index)
    }

    private func expand(_ p: [UInt8], _ secondFile: Bool, _ out: inout String, _ depth: Int) {
        guard depth <= 4 else { return }
        let world = World.shared
        var i = 0
        while i < p.count {
            let c = p[i]
            i += 1
            switch c {
            case 0x00..<0x80:
                if c == 0x0D { out += "\n" } else if c >= 0x20 { out.append(Swift.Character(Unicode.Scalar(c))) }
                // other control bytes are layout hints of the original renderer
            case 0x80:
                guard i + 1 < p.count else { return }
                let id = UInt16(p[i]) << 8 | UInt16(p[i + 1])
                i += 2
                expand(raw(id, secondFile), secondFile, &out, depth + 1)
            case 0x81..<0x90:
                let id = world.rawW(world.nameTable + 2 * Int(c & 0x0F))
                if id != 0 { expand(raw(id, secondFile), secondFile, &out, depth + 1) }
            case 0x90..<0xA0:
                guard i < p.count else { return }
                let variable = Int(p[i])
                i += 1
                out += c == 0x92 ? "\(world.w(variable))" : "\(world.b(variable))"
            case 0xA0..<0xD0:
                // extended characters: the font draws their low seven bits
                out.append(Swift.Character(Unicode.Scalar(c & 0x7F)))
            case 0xD0..<0xF0:
                i += c == 0xD0 ? 2 : c == 0xD1 ? 4 : 1
            case 0xFE:
                out.append(GameText.pageBreak)
            default:
                return // 0xF0-0xFD end a nested sentence, 0xFF the text
            }
        }
    }
}
