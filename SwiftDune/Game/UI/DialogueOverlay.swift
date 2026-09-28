//
//  DialogueOverlay.swift
//  SwiftDune
//
//  The original room dialogue uses PHRASE11.HSQ for the English text and
//  presents one condition-selected line at a time over the room/head view.
//  This small presenter deliberately reads that resource at runtime instead
//  of duplicating story prose in Swift.
//

import Foundation

final class DialogueOverlay: DuneNode {
    private var font: GameFont?
    private var phrases: Sentence?
    private var phraseIndex: UInt16 = 0
    private var text: String?
    /// The speaker's DIALOGUE character number (for the balloon's place).
    private var speakerNumber = 0
    private var icons: Sprite?
    private let tiles = PixelBuffer(width: 320, height: 200)
    private var speaker = ""

    init() {
        super.init("Dialogue")
    }

    override func onEnable() {
        font = GameFont()
        icons = Sprite("ICONES.HSQ")
        phrases = Sentence(.phrase1, language: .english)
    }

    override func onDisable() {
        font = nil
        phrases = nil
        phraseIndex = 0
        speaker = ""
    }

    override func onParamsChange() {
        if let index = params["phraseIndex"] as? Int {
            phraseIndex = UInt16(truncatingIfNeeded: index)
            text = nil
        }
        if let text = params["text"] as? String {
            // A page already expanded by the dialogue engine.
            self.text = text
        }
        if let speaker = params["speaker"] as? String {
            self.speaker = speaker
        }
        if let number = params["speakerNumber"] as? Int {
            speakerNumber = number
        }
    }

    /// The three voice balloons (ds:2224): x, y, width, height.
    private static let balloons: [(Int, Int, Int, Int)] = [(80, 14, 192, 72), (80, 16, 200, 86), (80, 8, 208, 97)]
    /// Right edge of each talking head's mouth box (ds:27fa).
    private static let mouthRight = [99, 105, 140, 101, 104, 114, 109, 114, 101, 113, 126, 120, 84, 86, 119, 137, 100]

    /// A conversation page in the original's balloon: ICONES 0x1C tiled
    /// over the first balloon tall enough, right of the speaker's mouth,
    /// the text on 10-pixel lines (ScummVM GameScreen::drawTalk/drawBubble).
    private func renderBalloon(_ page: String, _ buffer: PixelBuffer, _ font: GameFont, _ icons: Sprite) {
        let head = min(max(speakerNumber, 0), 16)
        var chosen = DialogueOverlay.balloons[2]
        var lines = 0
        for balloon in DialogueOverlay.balloons {
            let left = max(balloon.0, DialogueOverlay.mouthRight[head] + 24)
            let width = min(320, balloon.0 + balloon.2 + 24) - left
            lines = font.lineCount(page, width: width - 24, style: .normal)
            chosen = balloon
            if lines * 10 + 32 <= balloon.3 { break }
        }
        let left = max(chosen.0, DialogueOverlay.mouthRight[head] + 24)
        let right = min(320, chosen.0 + chosen.2 + 24)
        let top = chosen.1, height = chosen.3

        icons.setPalette()
        // Tile into a scratch buffer, then copy only the balloon's box.
        tiles.clearBuffer()
        var y = 0
        while y < height {
            var x = 0
            while x < right - left {
                icons.drawFrame(0x1C, x: Int16(x), y: Int16(y), buffer: tiles)
                x += 33
            }
            y += 29
        }
        for row in 0..<height where top + row < buffer.height {
            for column in 0..<(right - left) {
                buffer.rawPointer[(top + row) * buffer.width + left + column] = tiles.rawPointer[row * tiles.width + column]
            }
        }
        font.paletteIndex = 0
        font.render(page, rect: DuneRect(Int16(left + 12), Int16(top), UInt16(right - left - 24), UInt8(height)),
                    buffer: buffer, alignment: .justify, style: .normal)
    }


    override func render(_ buffer: PixelBuffer) {
        guard let font = font, let phrases = phrases else { return }

        if let page = text, let icons = icons {
            renderBalloon(page, buffer, font, icons)
            return
        }

        // Keep the room visible and use the dark subtitle strip below the
        // animation. The normal HUD remains available after the line closes.
        // Leave a complete text band below the speaker label. The dialogue
        // line commonly wraps to two or three 7-pixel small-font rows; the
        // old 10-pixel rectangle made the first row overlap the speaker and
        // clipped the final row at the bottom of the band.
        Primitives.fillRect(DuneRect(0, 132, 320, 36), 0, buffer, isOffset: false)
        font.paletteIndex = 250
        if !speaker.isEmpty {
            font.render(speaker, rect: DuneRect(6, 134, 90, 8), buffer: buffer,
                        alignment: .left, style: .small)
        }
        font.render(text ?? GameText.shared.phrase(Int(phraseIndex)).replacingOccurrences(of: "\u{FE}", with: " "),
                    rect: DuneRect(6, 143, 308, 21), buffer: buffer,
                    alignment: .left, style: .small)
    }
}

final class CommunicationOverlay: DuneNode {
    private var font: GameFont?
    private var phrases: Sentence?
    private var mode = 0 // 0 = message list, 1 = selected message
    private var phraseIndex: UInt16 = 225

    init() {
        super.init("Communication")
    }

    override func onEnable() {
        font = GameFont()
        phrases = Sentence(.phrase1, language: .english)
    }

    override func onDisable() {
        font = nil
        phrases = nil
        mode = 0
        phraseIndex = 225
    }

    override func onParamsChange() {
        if let mode = params["mode"] as? Int {
            self.mode = mode
        }
        if let phraseIndex = params["phraseIndex"] as? Int {
            self.phraseIndex = UInt16(truncatingIfNeeded: phraseIndex)
        }
    }

    override func render(_ buffer: PixelBuffer) {
        guard let font = font, let phrases = phrases else { return }
        Primitives.fillRect(DuneRect(0, 0, 320, 152), 0, buffer, isOffset: false)
        font.paletteIndex = 250
        font.render("COMMUNICATION ROOM", rect: DuneRect(8, 8, 304, 10),
                    buffer: buffer, alignment: .center, style: .small)

        if mode == 0 {
            font.render("VIEW NEW MESSAGES", rect: DuneRect(24, 34, 272, 10),
                        buffer: buffer, alignment: .left, style: .small)
            font.render("THE EMPEROR", rect: DuneRect(24, 52, 272, 10),
                        buffer: buffer, alignment: .left, style: .small)
            font.render("CANCEL", rect: DuneRect(24, 70, 272, 10),
                        buffer: buffer, alignment: .left, style: .small)
        } else {
            font.render("EMPEROR SHADDAM IV", rect: DuneRect(8, 34, 304, 10),
                        buffer: buffer, alignment: .center, style: .small)
            font.render(GameText.shared.phrase(Int(phraseIndex)).replacingOccurrences(of: "\u{FE}", with: " "),
                        rect: DuneRect(12, 56, 296, 36), buffer: buffer,
                        alignment: .justify, style: .small)
            font.render("CLICK TO RETURN", rect: DuneRect(8, 116, 304, 10),
                        buffer: buffer, alignment: .center, style: .small)
        }
    }
}
