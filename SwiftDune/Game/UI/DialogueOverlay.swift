//
//  DialogueOverlay.swift
//  SwiftDune
//
//  The speech balloon drawn behind a talking portrait. Floppy
//  show_voice_subtitle (seg000:88af): ICONES sprite 0x1C tiled into the
//  first balloon at seg001:2224 that can hold the line, then the tall-font
//  text. Glyphs are revealed one at a time while the portrait speaks.
//

import Foundation


private struct DialogueBalloon {
    var y: Int
    var width: Int
    var height: Int
}


private struct DialogueLine {
    var words: [[UInt8]]
    var advance: Int
    var pad: Int
}


private struct DialogueFrame {
    var x: Int
    var y: Int
    var height: Int
    var paintWidth: Int
    var penX: Int
    var penY: Int
    var justify: Bool
    var lines: [DialogueLine]
    var glyphCount: Int
}


final class DialogueOverlay: DuneNode {
    /// = seg001:2224, smallest first. x0 is replaced by the per-head origin.
    private static let balloons: [DialogueBalloon] = [
        DialogueBalloon(y: 0x0E, width: 0xC0, height: 0x48),
        DialogueBalloon(y: 0x10, width: 0xC8, height: 0x56),
        DialogueBalloon(y: 0x08, width: 0xD0, height: 0x61)
    ]

    /// = seg001:22a8 talking_head_balloon_x_table.
    private static let balloonOrigins: [Int] = [
        96, 90, 116, 96, 100, 104, 126, 104, 106, 112, 124, 96, 80, 80, 114, 116, 90
    ]

    /// ICONES sprite tiled across the balloon (seg000:8fcc).
    private static let panelSprite: UInt16 = 0x1C

    /// In-room insets from prepare_dialogue_presentation (seg000:9f6a).
    private static let padLeft = 0x28
    private static let padRight = 0x10
    private static let padTop = 0x10
    private static let padBottom = 0x10

    /// Tall-font colour (seg000:9f82) and the 10-pixel line step (seg000:8b2f).
    private static let textColor: UInt8 = 0xF0
    private static let lineHeight = 10

    /// One glyph per mouth frame (seg000:a7c2, 25 fps).
    private static let glyphInterval: TimeInterval = 1.0 / 25.0

    private var font: GameFont?
    private var icons: Sprite?
    private let tiles = PixelBuffer(width: 320, height: 200)

    private var text = ""
    private var speakerNumber = 0
    private var layout: DialogueFrame?
    private var layoutDirty = true
    private var visibleGlyphs = 0
    private var glyphTime: TimeInterval = 0
    private var varietySeed: UInt16 = 1

    init() {
        super.init("Dialogue")
    }


    override func onEnable() {
        if font == nil {
            font = GameFont()
        }
        if icons == nil {
            icons = Sprite("ICONES.HSQ")
        }
        layoutDirty = true
    }


    override func onDisable() {
        font = nil
        icons = nil
        layout = nil
        text = ""
        speakerNumber = 0
        layoutDirty = true
        visibleGlyphs = 0
        glyphTime = 0
    }


    override func onParamsChange() {
        var changed = false

        if let text = params["text"] as? String, text != self.text {
            self.text = text
            changed = true
        }

        if let speaker = params["speaker"] as? Int {
            if speaker != speakerNumber {
                speakerNumber = speaker
                changed = true
            }
        } else if let speaker = params["speaker"] as? DialogueSpeaker {
            let number = Int(speaker.rawValue)
            if number != speakerNumber {
                speakerNumber = number
                changed = true
            }
        }

        if changed {
            layoutDirty = true
            visibleGlyphs = 0
            glyphTime = 0
        }
    }


    override func update(_ elapsedTime: TimeInterval) {
        currentTime += elapsedTime
        rebuildLayoutIfNeeded()

        guard let layout, visibleGlyphs < layout.glyphCount else {
            return
        }

        glyphTime += elapsedTime
        while glyphTime >= DialogueOverlay.glyphInterval && visibleGlyphs < layout.glyphCount {
            glyphTime -= DialogueOverlay.glyphInterval
            visibleGlyphs += 1
        }
    }


    override func render(_ buffer: PixelBuffer) {
        rebuildLayoutIfNeeded()

        guard let layout, let icons else {
            return
        }

        paintPanel(layout, icons, buffer)
        paintText(layout, buffer)
    }


    private func rebuildLayoutIfNeeded() {
        guard layoutDirty, let font else {
            return
        }

        layout = makeLayout(text, font: font)
        layoutDirty = false
        if let layout, visibleGlyphs > layout.glyphCount {
            visibleGlyphs = layout.glyphCount
        }
    }


    /// = seg000:8ccd for a room line: three balloons, then the pad-dropped fallback.
    private func makeLayout(_ text: String, font: GameFont) -> DialogueFrame? {
        let bytes = dialogueBytes(text)
        let originX = balloonOrigin(speakerNumber)
        let count = DialogueOverlay.balloons.count
        var index = 0

        while index < count {
            let balloon = DialogueOverlay.balloons[index]
            let budget = balloon.width - DialogueOverlay.padLeft - DialogueOverlay.padRight
            let last = index + 1 == count

            if let lines = layoutLines(bytes, budget: budget, font: font) {
                let textHeight = lines.count * DialogueOverlay.lineHeight + DialogueOverlay.padTop + DialogueOverlay.padBottom
                if textHeight < balloon.height {
                    if !last && varietyBit() {
                        index += 1
                        continue
                    }
                    return makeFrame(originX, balloon, lines, DialogueOverlay.padTop, DialogueOverlay.padBottom)
                }

                if last {
                    guard DialogueOverlay.padBottom != 0,
                          let fitted = layoutLines(bytes, budget: budget, font: font) else {
                        return nil
                    }
                    return makeFrame(originX, balloon, fitted, 0, 0)
                }
            } else if last {
                return nil
            }

            index += 1
        }

        return nil
    }


    private func makeFrame(_ originX: Int, _ balloon: DialogueBalloon, _ lines: [DialogueLine], _ padTop: Int, _ padBottom: Int) -> DialogueFrame {
        var justify = true
        var lineIndex = 0
        while lineIndex < lines.count {
            let line = lines[lineIndex]
            if !line.words.isEmpty && line.advance >= 0x1E {
                justify = false
                break
            }
            lineIndex += 1
        }

        let heightBudget = balloon.height - padTop - padBottom
        let totalHeight = lines.count * DialogueOverlay.lineHeight
        let centered = max(0, heightBudget - totalHeight) / 2
        let paintRight = min(320, originX + balloon.width)

        return DialogueFrame(
            x: originX,
            y: balloon.y,
            height: balloon.height,
            paintWidth: max(0, paintRight - originX),
            penX: originX + DialogueOverlay.padLeft,
            penY: balloon.y + padTop + centered,
            justify: justify,
            lines: lines,
            glyphCount: countGlyphs(lines)
        )
    }


    /// = seg000:8e16. A word wider than the budget is the carry-set bail.
    private func layoutLines(_ bytes: [UInt8], budget: Int, font: GameFont) -> [DialogueLine]? {
        var lines: [DialogueLine] = []
        var words: [[UInt8]] = []
        var remaining = budget
        var size: FontSize = .normal
        var index = 0

        while true {
            let byte = index < bytes.count ? bytes[index] : 0xFF
            if byte & 0x80 != 0 {
                if !words.isEmpty {
                    lines.append(commitLine(&words, remaining))
                }
                break
            }

            index += 1

            if byte == 0x0D {
                lines.append(commitLine(&words, remaining))
                remaining = budget
                continue
            }

            if byte == 0x20 {
                continue
            }

            index -= 1
            let start = index
            var width = 0

            while index < bytes.count {
                let current = bytes[index]
                if current == 0x20 || current == 0x0D || current & 0x80 != 0 {
                    break
                }
                index += 1
                if current == 0x06 {
                    size = .small
                } else if current == 0x08 {
                    size = .normal
                } else if current >= 0x20 {
                    width += font.advanceWidth(current, style: size)
                }
            }

            if width == 0 {
                continue
            }

            let word = Array(bytes[start..<index])
            let need = width + 6

            if remaining - need >= 0 {
                remaining -= need
                words.append(word)
            } else if remaining - need + 6 >= 0 {
                words.append(word)
                lines.append(commitLine(&words, remaining - need + 6))
                remaining = budget
            } else if !words.isEmpty {
                lines.append(commitLine(&words, remaining))
                remaining = budget - need
                if remaining + 6 < 0 {
                    return nil
                }
                words.append(word)
            } else {
                return nil
            }
        }

        if lines.isEmpty {
            return nil
        }
        return lines
    }


    private func commitLine(_ words: inout [[UInt8]], _ remaining: Int) -> DialogueLine {
        let count = words.count
        let leftover = max(0, remaining)
        let advance: Int
        let pad: Int
        if count > 1 {
            advance = leftover / (count - 1) + 6
            pad = leftover % (count - 1)
        } else {
            advance = leftover + 6
            pad = 0
        }
        let line = DialogueLine(words: words, advance: advance, pad: pad)
        words.removeAll(keepingCapacity: true)
        return line
    }


    private func paintPanel(_ frame: DialogueFrame, _ icons: Sprite, _ buffer: PixelBuffer) {
        let width = frame.paintWidth
        let height = frame.height
        if width <= 0 || height <= 0 || frame.x >= buffer.width || frame.y >= buffer.height {
            return
        }

        tiles.clearBuffer()
        guard icons.frameCount > Int(DialogueOverlay.panelSprite) else {
            return
        }

        let sprite = icons.frame(at: Int(DialogueOverlay.panelSprite))
        let tileWidth = Int(sprite.width)
        let tileHeight = Int(sprite.height)
        if tileWidth > 0 && tileHeight > 0 {
            var y = 0
            while y < height {
                var x = 0
                while x < width {
                    icons.drawFrame(DialogueOverlay.panelSprite, x: Int16(x), y: Int16(y), buffer: tiles)
                    x += tileWidth
                }
                y += tileHeight
            }
        }

        let rowBytes = min(width, buffer.width - frame.x)
        let rows = min(height, buffer.height - frame.y)
        if rowBytes <= 0 || rows <= 0 {
            return
        }

        var row = 0
        while row < rows {
            let source = tiles.rawPointer.advanced(by: row * tiles.width)
            let destination = buffer.rawPointer.advanced(by: (frame.y + row) * buffer.width + frame.x)
            memcpy(destination, source, rowBytes)
            row += 1
        }
    }


    private func paintText(_ frame: DialogueFrame, _ buffer: PixelBuffer) {
        guard let font, visibleGlyphs > 0 else {
            return
        }

        font.paletteIndex = DialogueOverlay.textColor
        var foreground = DialogueOverlay.textColor
        var background: UInt8 = 0
        var size: FontSize = .normal
        var remaining = visibleGlyphs
        let lastLine = frame.lines.count - 1
        var lineIndex = 0

        while lineIndex < frame.lines.count {
            let line = frame.lines[lineIndex]
            let justify = frame.justify && lineIndex != lastLine
            let advance = justify ? line.advance : 6
            var pad = justify ? line.pad : 0
            var x = frame.penX
            let y = frame.penY + lineIndex * DialogueOverlay.lineHeight
            var wordIndex = 0

            while wordIndex < line.words.count {
                if wordIndex != 0 {
                    var gap = advance
                    if pad > 0 {
                        gap += 1
                        pad -= 1
                    }
                    x += gap
                }

                for byte in line.words[wordIndex] {
                    if byte < 0x20 {
                        if byte == 0x01 {
                            swap(&foreground, &background)
                            font.paletteIndex = foreground
                        } else if byte == 0x06 {
                            size = .small
                        } else if byte == 0x08 {
                            size = .normal
                        }
                        continue
                    }

                    if remaining == 0 {
                        return
                    }

                    x += font.drawGlyph(byte, x: x, y: y, buffer: buffer, style: size)
                    remaining -= 1
                }

                wordIndex += 1
            }

            lineIndex += 1
        }
    }


    private func countGlyphs(_ lines: [DialogueLine]) -> Int {
        var count = 0
        for line in lines {
            for word in line.words {
                for byte in word where byte >= 0x20 {
                    count += 1
                }
            }
        }
        return count
    }


    private func balloonOrigin(_ speaker: Int) -> Int {
        if speaker == 0x2D {
            return 98
        }
        if speaker >= 0 && speaker < DialogueOverlay.balloonOrigins.count {
            return DialogueOverlay.balloonOrigins[speaker]
        }
        return 80
    }


    /// Printable bytes, stopped at the high-bit terminator (0xFE / 0xFF).
    private func dialogueBytes(_ text: String) -> [UInt8] {
        var bytes: [UInt8] = []
        bytes.reserveCapacity(text.unicodeScalars.count + 1)
        for scalar in text.unicodeScalars {
            if scalar.value >= 0x80 {
                break
            }
            bytes.append(UInt8(truncatingIfNeeded: scalar.value))
        }
        bytes.append(0xFF)
        return bytes
    }


    /// = seg000:e3cc rand, low bit. Bumps a fitting balloon to the next size.
    private func varietyBit() -> Bool {
        let product = UInt32(varietySeed) &* 0xCBD1
        let seed = UInt16(truncatingIfNeeded: product & 0xFFFF) &+ 1
        varietySeed = seed
        let value = (UInt16(truncatingIfNeeded: (product >> 16) & 0xFF) << 8) | (seed >> 8)
        return value & 1 != 0
    }
}
