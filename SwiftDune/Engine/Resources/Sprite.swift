//
//  Sprite.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 24/08/2023.
//

import Foundation
import CoreGraphics
import AppKit


class SpriteFrameInfo {
    var startOffset: UInt32 = 0
    var isCompressed: Bool = false
    var width: UInt16 = 0
    var height: UInt16 = 0
    var bytesPerRow: UInt16 = 0
    var paletteOffset: UInt8 = 0
    var paletteIndices: UnsafeMutablePointer<UInt8>
    
    init(_ bufferSize: Int) {
        paletteIndices = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
    }
    
    deinit {
        paletteIndices.deallocate()
    }
}

final class Sprite: Equatable {
    static func == (lhs: Sprite, rhs: Sprite) -> Bool {
        return lhs.resource.fileName == rhs.resource.fileName
    }
    
    
    private let engine: DuneEngine = DuneEngine.shared
    private var resource: Resource
    
    private var palette: [PaletteChunk] = []
    private var alternatePalettes: [PaletteChunk] = []

    private var frameIndexOffset: UInt32 = 0
    private var animationOffset: UInt32 = 0

    private var animations: [SpriteAnimation] = []
    private var frames: [SpriteFrameInfo] = []
    
    var fileName: String {
        return resource.fileName
    }
    var frameCount: Int {
        return frames.count
    }
    
    var animationCount: Int {
        return animations.count
    }
    
    var alternatePalettesCount: Int {
        return alternatePalettes.count
    }
    
    private var currentAnimationIndex: UInt16 = 0
    private var currentAnimationFrameIndex: UInt16 = 0
    
    private let animationFrameRate: Double = 12.0
    
    private let rect = NSRect(x: 0, y: 0, width: 320, height: 200)
    
    init(_ fileName: String) {
        self.resource = Resource(fileName)
        
        self.parsePalette()
        self.parseFrames()
        
        if resource.fileName == "SUNRS.HSQ" || resource.fileName == "BALCON.HSQ" || resource.fileName == "SKY.HSQ" {
            self.parseAlternatePalettes()
        } else {
            animations = SpriteAnimation.parseAnimations(resource, animationOffset: animationOffset)
        }
        
        if palette.count > 0 {
            self.setPalette()
        }
    }

    
    func saveAs(_ fileName: String) {
        resource.stream!.saveAs(fileName)
    }
    
    
    func parsePalette() {
        resource.stream!.seek(0)
        
        let chunkSize = resource.stream!.readUInt16LE()
        let currentPos: UInt16 = 2
        
        if chunkSize == currentPos {
            return
        }
        
        while true {
            let paletteStart = UInt16(resource.stream!.readByte())
            let paletteCount = UInt16(resource.stream!.readByte())
            
            // 0xFFFF marks the end of palette block
            if paletteStart == 0xFF && paletteCount == 0xFF {
                break
            }
            
            if paletteCount == 0 {
                break
            }
            
            var paletteChunk = Array<UInt32>(repeating: 0, count: Int(paletteCount))
            
            var i: UInt16 = 0
            
            while i < paletteCount {
                if i + paletteStart > 256 {
                    break
                }
                
                let r = UInt32(resource.stream!.readByte() << 2)
                let g = UInt32(resource.stream!.readByte() << 2)
                let b = UInt32(resource.stream!.readByte() << 2)
                let a = UInt32(0xFF)
                
                paletteChunk[Int(i)] = (a << 24) | (b << 16) | (g << 8) | r
                i += 1
            }
        
            palette.append(PaletteChunk(chunk: paletteChunk, start: Int(paletteStart), count: Int(paletteCount)))
        }
    }

     
    func setPalette() {
        var i = 0
        
        while i < palette.count {
            engine.palette.update(&palette[i].chunk, start: palette[i].start, count: palette[i].count)
            i += 1
        }
    }

    
    func setAlternatePalette(_ index: Int, _ prevIndex: Int = -1, blend: CGFloat = 1.0) {
        guard index < alternatePalettes.count else {
            return
        }
        
        let paletteStart = alternatePalettes[index].start
        let paletteCount = alternatePalettes[index].count

        var chunk = Array<UInt32>(alternatePalettes[index].chunk)

        if blend < 1.0 && prevIndex > -1 {
            let prevChunk = Array<UInt32>(alternatePalettes[prevIndex].chunk)

            var i = 0

            let a = UInt32(0xFF)

            while i < paletteCount {
                let r2 = UInt32(chunk[i]) & 0xFF
                let g2 = UInt32(chunk[i] >> 8) & 0xFF
                let b2 = UInt32(chunk[i] >> 16) & 0xFF

                let r1 = UInt32(prevChunk[i]) & 0xFF
                let g1 = UInt32(prevChunk[i] >> 8) & 0xFF
                let b1 = UInt32(prevChunk[i] >> 16) & 0xFF
                
                let r = Math.lerp(r1, r2, blend)
                let g = Math.lerp(g1, g2, blend)
                let b = Math.lerp(b1, b2, blend)
                
                chunk[i] = (a << 24) | (b << 16) | (g << 8) | r
                i += 1
            }
        }
        
        engine.palette.update(&chunk, start: paletteStart, count: paletteCount)
    }
    
    
    func parseAlternatePalettes() {
        while !resource.stream!.isEOF() {
            let header = resource.stream!.readUInt16LE(peek: true)
            
            if header != 0x0000 {
                engine.logger.log(.error, "parseAlternatePalettes(): ERROR - header should be 0x0000")
                break
            }
            
            resource.stream!.skip(2)
            
            let chunkSize = resource.stream!.readUInt16LE()

            if chunkSize <= 2 {
                engine.logger.log(.error, "parseAlternatePalettes(): ERROR - invalid chunk size")
                break
            }

            let paletteStart = UInt16(resource.stream!.readByte())
            let paletteCount = UInt16(resource.stream!.readByte())
            
            if chunkSize - 2 != paletteCount * 3 {
                engine.logger.log(.error, "parseAlternatePalettes(): not a palette part")
                resource.stream!.seek(resource.stream!.offset - 6)
                break
            }
            
            var paletteChunk = Array<UInt32>(repeating: 0, count: Int(paletteCount))
            var i: UInt16 = 0
            
            while i < paletteCount {
                if i + paletteStart > 256 {
                    break
                }
                
                let r = UInt32(resource.stream!.readByte() << 2)
                let g = UInt32(resource.stream!.readByte() << 2)
                let b = UInt32(resource.stream!.readByte() << 2)
                let a = UInt32(0xFF)
                
                paletteChunk[Int(i)] = (a << 24) | (b << 16) | (g << 8) | r
                i += 1
            }
        
            alternatePalettes.append(PaletteChunk(chunk: paletteChunk, start: Int(paletteStart), count: Int(paletteCount)))
        }
    }
    
    
    private func parseFrames() {
        resource.stream!.seek(0)
        
        frameIndexOffset = UInt32(resource.stream!.readUInt16LE())
        resource.stream!.seek(frameIndexOffset)

        // Offset to first image gives the size of the frame index header and
        // the number of frames (2 bytes per offset)
        let firstFrameOffset = UInt32(resource.stream!.readUInt16LE(peek: true))
        let frameCount = (firstFrameOffset / 2)
        
        for i in 0..<frameCount {
            resource.stream!.seek(frameIndexOffset + 2 * i)

            let frameOffset = UInt32(resource.stream!.readUInt16LE())
            
            let frameStartOffset = frameIndexOffset + frameOffset
            resource.stream!.seek(frameStartOffset)

            // If two first bytes are 0x0000 we are looking at something else than an image part
            if resource.stream!.readUInt16LE(peek: true) == 0x0000 {
                //engine.logger.log(.debug, "parseFrames(): skipping frame=\(i), frameOffset=\(frameInfo.startOffset)")
                break
            }
            
            let w0 = resource.stream!.readUInt16LE()
            let w1 = resource.stream!.readUInt16LE()

            let flags = UInt8((w0 & 0xFE00) >> 8)
            let width = UInt16(w0 & 0x01FF)
            let height = UInt16(w1 & 0x00FF)
            let paletteOffset = UInt8((w1 & 0xFF00) >> 8)
            let isCompressed = (flags & 0x80) > 0

            //engine.logger.log(.debug, "parseFrames(): frame=\(i), frameOffset=\(frameStartOffset), width=\(width), height=\(height), flags=\(String.fromByte(flags)) compressed=\(isCompressed ? "YES" : "NO")")

            var bytesPerRow = (width + 1) / 2

            // Re-add 1 to transform an odd number of pixels to read into an even number of pixels to read.
            if bytesPerRow % 2 == 1 {
                bytesPerRow += 1
            }

            let frameInfo = SpriteFrameInfo(2 * Int(width) * Int(height))
            frameInfo.startOffset = frameStartOffset + 4
            frameInfo.isCompressed = isCompressed
            frameInfo.bytesPerRow = bytesPerRow
            frameInfo.width = width
            frameInfo.height = height
            frameInfo.paletteOffset = paletteOffset
         
            // Skip 4 bytes of frame header to access the pixels
            resource.stream!.seek(frameInfo.startOffset)
            
            // FIXME: sprites without palette seems to have an extra 2-byte value to read?
            if fileName.starts(with: "DUNES") {
                resource.stream!.skip(2)
            }
            
            if !frameInfo.isCompressed {
                compute4bpp(frameInfo)
            } else {
                compute4bppRLE(frameInfo)
            }

            frames.append(frameInfo)
        }
        
        animationOffset = resource.stream!.offset
                
        setPalette()
        
      engine.logger.log(.debug, "parseFrames(): finished reading. resource size=\(resource.stream!.size), anim offset=\(animationOffset)")
    }
    
    
    func frame(at index: Int) -> SpriteFrameInfo {
        return frames[index]
    }

    
    func animation(at index: Int) -> SpriteAnimation {
        return animations[index]
    }
    
    
    func moveAnimation(_ index: Int, to sprite: Sprite) {
        sprite.addAnimation(animations[index])
        animations.remove(at: index)
    }
    
    
    func addAnimation(_ animation: SpriteAnimation) {
        animations.append(animation)
    }
    
    
    func drawAnimation(_ animIndex: UInt16, buffer: PixelBuffer, time: Double = 0.0, offset: DunePoint = .zero, loop: Bool = true) {
        guard animIndex < animations.count else {
            engine.logger.log(.error, "Invalid animation index: \(animIndex)")
            return
        }

        let animation = animations[Int(animIndex)]
        
        let frameIndex = loop ? Int(time / (1.0 / animationFrameRate)) % animation.frames.count : min(Int(time / (1.0 / animationFrameRate)), animation.frames.count - 1)
        let animationFrame = animation.frames[frameIndex]
        
        var m = 0
        
        while m < animationFrame.groups.count {
            let group = animationFrame.groups[m]
            var n = 0
            
            while n < group.images.count {
                let x = animation.x + group.images[n].xOffset + offset.x
                let y = animation.y + group.images[n].yOffset + offset.y
                
                drawFrame(group.images[n].imageNumber, x: x, y: y, buffer: buffer)
                n += 1
            }
            
            m += 1
        }
    }

    
    func drawFrame(_ index: UInt16, x: Int16, y: Int16, buffer: PixelBuffer, effect: SpriteEffect = .none) {
        drawFrame(index, x: x, y: y, buffer: buffer, effects: [effect])
    }
    
    
    func drawFrame(_ index: UInt16, x: Int16, y: Int16, buffer: PixelBuffer, effects: [SpriteEffect]) {
        if index == 255 {
            return
        }
        
        let bufferWidth = buffer.width
        let bufferHeight = buffer.height
        
        let frameInfo = frames[Int(index)]
        var frameWidth = Int(frameInfo.width)
        var frameHeight = Int(frameInfo.height)
        var roomPaletteOffset: Int = 0
        let scaledFrameWidth = frameWidth
        
        // Effects
        var flipX = false
        var flipY = false
        var scaleRatio = 1.0
      
        var effectIndex = 0
        
        while effectIndex < effects.count {
            switch effects[effectIndex] {
            case .transform(let offset, let flipHorizontal, let flipVertical, let scaleFactor):
                flipX = flipHorizontal
                flipY = flipVertical
                roomPaletteOffset = offset != 0 ? Int(offset) - Int(frameInfo.paletteOffset) : 0
                
                if scaleFactor != 1.0 {
                    scaleRatio = scaleFactor
                    frameWidth = Int(Double(frameWidth) * scaleRatio)
                    frameHeight = Int(Double(frameHeight) * scaleRatio)
                }

                break
            default:
                break
            }
          
            effectIndex += 1
        }
        
        // Do not render sprites outside the screen
        let x1 = Int(x)
        let y1 = Int(y)
        let x2 = x1 + frameWidth
        let y2 = y1 + frameHeight
        
        // Skip drawing of the image if outside of canvas
        if x1 > bufferWidth || y1 > bufferHeight || x2 < 0 || y2 < 0 {
            return
        }
        
        // Bounds for sprite frame part inside buffer rect
        let minX1 = max(0, x1)
        let maxX2 = min(x2, bufferWidth)
        let minY1 = max(0, y1)
        let maxY2 = min(y2, bufferHeight)
        
        var j = minY1

        while j < maxY2 {
            var i = minX1
            let yDelta = j - y1
            let yRatio = Int(CGFloat(yDelta) / scaleRatio)
            let yScaled = yRatio * scaledFrameWidth

            while i < maxX2 {
                let xDelta = i - x1
                let srcIndex = yScaled + Int(CGFloat(xDelta) / scaleRatio)
                var paletteIndex = frameInfo.paletteIndices[srcIndex]

                if paletteIndex <= frameInfo.paletteOffset || paletteIndex == 0 {
                    i += 1
                    continue
                }
                
                paletteIndex = UInt8(Int(paletteIndex) + roomPaletteOffset)

                let x = flipX ? x2 - xDelta - 1 : i
                let y = flipY ? y2 - yDelta - 1 : j
                
                let destIndex = y * bufferWidth + x
                
                if paletteIndex == 0x00 {
                    i += 1
                    continue
                }
                
                buffer.rawPointer[destIndex] = paletteIndex

                i += 1
            }
            
            j += 1
        }
    }
    
    
    private func compute4bpp(_ frameInfo: SpriteFrameInfo) {
        var pixel: UInt8 = 0
        let paletteOffset = frameInfo.paletteOffset
        let width = Int(frameInfo.width)
        var y = 0
        
        while y < frameInfo.height {
            var x = 0
            var lineRemain = 4 * ((frameInfo.width + 3) / 4)
            
            repeat {
                pixel = resource.stream!.readByte()
                
                let paletteIndex1 = UInt8(pixel & 0xF)
                let paletteIndex2 = UInt8(pixel >> 4)

                if x < frameInfo.width {
                    let index1 = width * y + x
                    frameInfo.paletteIndices[index1] = paletteIndex1 + paletteOffset
                }

                x += 1

                if x < frameInfo.width {
                    let index2 = width * y + x
                    frameInfo.paletteIndices[index2] = paletteIndex2 + paletteOffset
                }

                x += 1
                lineRemain -= 2
            } while lineRemain > 0
            
            y += 1
        }
    }

    
    private func compute4bppRLE(_ frameInfo: SpriteFrameInfo) {
        var pixel: UInt8 = 0
        var count: Int = 0
        let totalSize = UInt32(frameInfo.bytesPerRow * 2) * UInt32(frameInfo.height)
        var current: UInt32 = 0
        let paletteOffset = frameInfo.paletteOffset

        func getIndex(_ pt: UInt32) -> Int {
            let dx = Int(pt % UInt32(frameInfo.bytesPerRow * 2))
            let dy = Int(pt / UInt32(frameInfo.bytesPerRow * 2))
            
            return (dy * Int(frameInfo.width)) + dx
        }
        
        while current < totalSize {
            let repetition = Int16(resource.stream!.readSByte())
            let fillSingleValue = repetition < 0
            
            count = Int((fillSingleValue ? -repetition : repetition) + 1)
            pixel = fillSingleValue ? resource.stream!.readByte() : 0
            
            var n = 0
            
            while n <= count - 1 {
                if !fillSingleValue {
                    pixel = resource.stream!.readByte()
                }
                
                let paletteIndex1 = UInt8(pixel & 0xf)
                let index1 = getIndex(current)
                frameInfo.paletteIndices[index1] = paletteIndex1 + paletteOffset
                
                current += 1
                
                if current >= totalSize {
                    break
                }
                
                let paletteIndex2 = UInt8(pixel >> 4)
                let index2 = getIndex(current)

                frameInfo.paletteIndices[index2] = paletteIndex2 + paletteOffset
                current += 1
                
                if current >= totalSize {
                    break
                }
                
                n += 1
            }
        }
    }
    
    
    func mergeFrames(with sprite: Sprite) {
        frames.append(contentsOf: sprite.frames)
    }
    
    
    func debugBytes(_ byteCount: UInt32) {
        let bytes = resource.stream!.readBytes(byteCount, peek: true)
        engine.logger.log(.debug, "\(byteCount) BYTES: \(bytes.map { String.fromByte($0) })")
    }
    
    
    func dumpInfo() throws {
        engine.logger.log(.debug, "------")
        engine.logger.log(.debug, "Sprite name: \(resource.fileName)")
        engine.logger.log(.debug, "Frame count: \(frames.count)")
        
        for i in 0..<frames.count {
            engine.logger.log(.debug, "Frame #\(i): width=\(frames[i].width), height=\(frames[i].height), compressed=\(frames[i].isCompressed ? "YES": "NO"), paletteOffset=\(frames[i].paletteOffset)")
        }
        
        engine.logger.log(.debug, "Animation count: \(animations.count)")
        
        for i in 0..<animations.count {
            engine.logger.log(.debug, "Animation #\(i): width=\(animations[i].width), height=\(animations[i].height), frames=\(animations[i].frames.count)")
            
            for j in 0..<animations[i].frames.count {
                let frame = animations[i].frames[j]

                engine.logger.log(.debug, "- Frame #\(j): groups=\(frame.groups.count)")
                
                for k in 0..<frame.groups.count {
                    let group = frame.groups[k]

                    engine.logger.log(.debug, "  - Group #\(k): images=\(group.images.count)")
                    
                    for l in 0..<group.images.count {
                        engine.logger.log(.debug, "    - Image #\(l): frame=\(group.images[l].imageNumber), x=\(group.images[l].xOffset), y=\(group.images[l].yOffset)")
                    }
                }
            }
        }
        
        engine.logger.log(.debug, "------")
    }
}

extension String {
    static func fromByte(_ b: UInt8) -> String {
        return String(format: "%02X", b)
    }
    
    static func fromWord(_ w: UInt16) -> String {
        return String(format: "%04X", w)
    }
    
    static func fromDWord(_ w: UInt32) -> String {
        return String(format: "%08X", w)
    }
}
