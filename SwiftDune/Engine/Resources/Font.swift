//
//  Font.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 17/10/2023.
//

import Foundation
import AppKit


enum FontAlignment {
    case left
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

    var color: DuneColor = .white
    
    init() {
        self.resource = Resource("DUNECHAR.HSQ")

        resource.stream!.seek(0)
        self.charWidths = resource.stream!.readBytes(256)
    }
    
    
    // TODO: justify text except last line
    // TODO: center vertically on the 48px height
    func render(_ text: String, rect: DuneRect, buffer: PixelBuffer, alignment: FontAlignment = .left, style: FontSize = .normal) {
        // TODO: Compute number of lines and space justification for each line
        
        // 1. Calculate the width of each word
        // 2. Calculate the words that fit for each line
        // 3. For each line compute space for justification and render

        let charHeight: Int = style == .normal ? 9 : 7
        var spaceWidth = 5 //Int(self.charWidths[32])

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
            let horizontalAlignment = n < lines.count - 1 ? alignment : .left
            self.drawText(lines[n], x: x, y: y, width: rect.width, buffer: buffer, style: style, alignment: horizontalAlignment)
            
            n += 1
        }
    }
    
    
    private func width(for text: String, style: FontSize) -> Int {
        var width = 0
        var i = 0
        
        while i < text.count {
            let char = text[i].utf8.first!.byteSwapped
            
            var charWidth = self.charWidths[Int(char)]
            
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
        var argbColor: UInt32 = color.asARGB
        
        var spaces: [Int] = []
        
        if alignment == .justify {
            let wordsWidth = words.reduce(0) { $0 + $1.size }
            let spaceSize = (Int(width) - wordsWidth) / (words.count - 1)

            spaces = Array<Int>(repeating: spaceSize, count: words.count - 1)

            let remainingSpace = Int(width) - wordsWidth - (spaceSize * (words.count - 1))
            
            for i in 0..<remainingSpace {
                spaces[i % (spaces.count)] += 1
            }
        } else if alignment == .left {
            var spaceWidth = Int(self.charWidths[32])
            
            if style == .small {
                spaceWidth = min(6, spaceWidth)
            }
            
            spaces = Array<Int>(repeating: spaceWidth, count: words.count - 1)
        }
        
        var j = 0

        while j < words.count {
            var i = 0
            let word = words[j]

            // Spacing
            if j > 0 && j < words.count {
                currentX += spaces[j - 1]
            }

            while i < word.text.count {
                let char = word.text[i].utf8.first!.byteSwapped
                
                var charWidth = self.charWidths[Int(char)]
                
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
                        let destOffset = (currentY + charY) * buffer.width + (currentX + charX)

                        if charLine & 0x80 > 0 {
                            memcpy(buffer.rawPointer + destOffset, &argbColor, 4)
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
    
    init(engine: DuneEngine) {
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
