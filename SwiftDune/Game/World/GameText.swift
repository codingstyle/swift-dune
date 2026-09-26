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

    /// Text of a COMMAND entry (0-based index), printable characters only.
    func command(_ index: Int) -> String {
        String(bytes: commands.rawBytes(at: UInt16(index)).filter { $0 >= 0x20 && $0 < 0x80 }, encoding: .isoLatin1) ?? ""
    }

    private lazy var commandTexts: [String] = (0..<Int(commands.sentenceCount())).map { command($0) }

    /// The COMMAND index whose text starts with `text` (the numbering
    /// differs between releases, so rows are looked up by text).
    func findCommand(_ text: String) -> Int? {
        // Leading spaces differ between releases ("  Cancel", "Done").
        let wanted = text.trimmingCharacters(in: .whitespaces)
        return commandTexts.firstIndex { $0.trimmingCharacters(in: .whitespaces).hasPrefix(wanted) }
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
