//
//  Font.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 17/10/2023.
//

import Foundation
import CoreGraphics


enum FontAlignment {
    case left
    case center
    case justify
}

enum FontSize {
    case small
    case normal
}


struct FontStyle {
    var fontSize: FontSize = .normal
    var horizontalAlignment: FontAlignment = .left
}


struct SizedText {
    var text: String
    var size: Int
}


final class GameFont {
    private var resource: Resource
    private var charWidths: [UInt8]

    var paletteIndex: UInt8 = 128
    
    init() {
        self.resource = Resource("DUNECHAR.HSQ")

        resource.stream!.seek(0)
        self.charWidths = resource.stream!.readBytes(256)
    }

    /// Convert a Swift character to an index in the original DOS font.
    ///
    /// The command text is decoded from the game's ISO-8859-1 data, but Swift
    /// strings can contain Unicode scalars which do not have a corresponding
    /// glyph in DUNECHAR.HSQ.  The resource has 128 glyphs per font size,
    /// even though its width table has 256 entries. Never let an extended
    /// value escape into the glyph data: story text must remain renderable.
    private func characterIndex(_ character: Swift.Character) -> Int {
        guard let scalar = String(character).unicodeScalars.first,
              scalar.value < 128 else {
            return charWidths.indices.contains(63) ? 63 : 0 // '?'
        }

        let index = Int(scalar.value)
        return charWidths.indices.contains(index) ? index : (charWidths.indices.contains(63) ? 63 : 0)
    }

    private var spaceWidth: Int {
        charWidths.indices.contains(32) ? Int(charWidths[32]) : 5
    }
    
    
    // TODO: justify text except last line
    // TODO: center vertically on the 48px height
    func render(_ text: String, rect: DuneRect, buffer: PixelBuffer, alignment: FontAlignment = .left, style: FontSize = .normal) {
        // TODO: Compute number of lines and space justification for each line
        
        // 1. Calculate the width of each word
        // 2. Calculate the words that fit for each line
        // 3. For each line compute space for justification and render

        let charHeight: Int = style == .normal ? 9 : 7
        var spaceWidth = self.spaceWidth

        if style == .small {
            spaceWidth = min(6, spaceWidth)
        }

        let words = text.split(separator: /\s/)
        var lineWidth = 0
        var i = 0
        
        var lines: [[SizedText]] = []
        var sizedText: [SizedText] = []
        
        while i < words.count {
            let word = String(words[i])
            let wordWidth = self.width(for: word, style: style)
            
            if lineWidth + (spaceWidth * (sizedText.count + 1)) + wordWidth < rect.width {
                sizedText.append(SizedText(text: word, size: wordWidth))
                lineWidth += wordWidth
            } else {
                lines.append(sizedText)
                
                sizedText = [SizedText(text: word, size: wordWidth)]
                lineWidth = wordWidth
            }
            
            i += 1
        }
        
        lines.append(sizedText)

        let yOffset = (Int(rect.height) - (lines.count * charHeight)) / 2
        var n = 0
        
        while n < lines.count {
            let x = UInt16(rect.x)
            let y = UInt16(Int(rect.y) + yOffset + (n * charHeight))
            let horizontalAlignment = n < lines.count - 1 || alignment != .justify ? alignment : .left
            self.drawText(lines[n], x: x, y: y, width: rect.width, buffer: buffer, style: style, alignment: horizontalAlignment)
            
            n += 1
        }
    }
    
    
    /// How many lines render() will use for `text` in `width` pixels.
    func lineCount(_ text: String, width: Int, style: FontSize) -> Int {
        let space = style == .small ? min(6, spaceWidth) : spaceWidth
        var lines = 1, lineWidth = 0, words = 0
        for word in text.split(separator: /\s/) {
            let w = self.width(for: String(word), style: style)
            if lineWidth + space * (words + 1) + w < width {
                lineWidth += w
                words += 1
            } else {
                lines += 1
                lineWidth = w
                words = 1
            }
        }
        return lines
    }


    /// The longest prefix of `text` that fits in `width` pixels on one line
    /// (command rows never wrap).
    func fit(_ text: String, width: Int, style: FontSize) -> String {
        // Measured the way render() lays a line out: word widths plus one
        // space width between words.
        let space = style == .small ? min(6, spaceWidth) : spaceWidth
        func lineWidth(_ line: String) -> Int {
            let words = line.split(separator: " ")
            // render() keeps a word on the line while the words so far plus
            // one space per word stay under the width.
            return words.reduce(0) { $0 + self.width(for: String($1), style: style) } + space * words.count
        }
        var result = text
        while !result.isEmpty && lineWidth(result) >= width {
            result.removeLast()
        }
        return result
    }


    private func width(for text: String, style: FontSize) -> Int {
        var width = 0
        var i = 0
        
        while i < text.count {
            let char = characterIndex(text[i])

            var charWidth = self.charWidths[char]
            
            if style == .small {
                charWidth = min(6, charWidth)
            }

            width += Int(charWidth)
            i += 1
        }

        return width
    }
    
    
    private func drawText(_ words: [SizedText], x: UInt16, y: UInt16, width: UInt16, buffer: PixelBuffer, style: FontSize = .normal, alignment: FontAlignment = .left) {
        var currentX = Int(x)
        let currentY = Int(y)
        let charHeight: UInt32 = style == .normal ? 9 : 7
        let offset: UInt32 = style == .normal ? 256 : 1408
        var spaces: [Int] = []

        // Empty sentences are valid in the original command table.  More
        // importantly, centered text still needs an entry for every gap
        // between words: the old code only populated `spaces` for left and
        // justified text, then indexed it while drawing a centered sentence.
        guard !words.isEmpty else {
            return
        }

        var interWordSpace = self.spaceWidth
        if style == .small {
            interWordSpace = min(6, interWordSpace)
        }
        
        if alignment == .justify {
            let wordsWidth = words.reduce(0) { $0 + $1.size }
            let gapCount = words.count - 1
            if gapCount == 0 {
                spaces = []
            } else {
                let spaceSize = (Int(width) - wordsWidth) / gapCount

                spaces = Array<Int>(repeating: spaceSize, count: gapCount)

                let remainingSpace = max(0, Int(width) - wordsWidth - (spaceSize * gapCount))
            
                for i in 0..<remainingSpace {
                    spaces[i % spaces.count] += 1
                }
            }
        } else if alignment == .left {
            spaces = Array<Int>(repeating: interWordSpace, count: words.count - 1)
        } else if alignment == .center {
            // Calculate text size including spaces
            let wordsWidth = words.reduce(0) { $0 + $1.size }
            let textWidth = wordsWidth + (interWordSpace * (words.count - 1))
            
            currentX += (Int(width) - textWidth) / 2
            spaces = Array<Int>(repeating: interWordSpace, count: words.count - 1)
        }
        
        var j = 0

        while j < words.count {
            var i = 0
            let word = words[j]

            // Spacing
            if j > 0, spaces.indices.contains(j - 1) {
                currentX += spaces[j - 1]
            }

            while i < word.text.count {
                let char = characterIndex(word.text[i])

                var charWidth = self.charWidths[char]
                
                if style == .small {
                    charWidth = min(6, charWidth)
                }
                
                let srcOffset = offset + UInt32(char) * charHeight
                resource.stream!.seek(srcOffset)
                
                var charLine: UInt8 = 0
                var charY = 0
                
                while charY < charHeight {
                    charLine = resource.stream!.readByte()

                    var charX = 0
                    
                    while charX < charWidth {
                        let destinationX = currentX + charX
                        let destinationY = currentY + charY

                        // Results and dialogue text come from binary sentence
                        // tables and can be wider than their destination
                        // rectangle. Clip at the framebuffer edge instead of
                        // allowing a long line to crash the app.
                        if charLine & 0x80 > 0,
                           destinationX >= 0,
                           destinationX < buffer.width,
                           destinationY >= 0,
                           destinationY < buffer.height {
                            let destOffset = destinationY * buffer.width + destinationX
                            buffer.rawPointer[destOffset] = paletteIndex
                        }

                        charLine <<= 1
                        charX += 1
                    }
                    
                    charY += 1
                }

                currentX += Int(charWidth)
                i += 1
            }
            
            j += 1
        }
    }
}


final class LargeFont {
    private var sprite: Sprite
    
    private let spaceWidth = 16
    private let fontOffset = 32
    
    init() {
        self.sprite = Sprite("GENERIC.HSQ")
    }
    
    func setPalette() {
        sprite.setPalette()
    }
    
    func render(_ text: String, x: UInt16, y: UInt16, buffer: PixelBuffer) {
        var currentX = x

        var i = 0
        
        while i < text.count {
            if text[i] == " " {
                currentX += UInt16(spaceWidth)
                i += 1
                continue
            }
            
            let char = Int(text[i].asciiValue!) - fontOffset
            let frameInfo = sprite.frame(at: char)
            
            sprite.drawFrame(UInt16(char), x: Int16(currentX), y: Int16(y), buffer: buffer)
            currentX += frameInfo.width + 1
            i += 1
        }
    }
}


extension StringProtocol {
    subscript(offset: Int) -> Swift.Character {
        let i = self.index(startIndex, offsetBy: offset)
        return self[i]
    }
}
