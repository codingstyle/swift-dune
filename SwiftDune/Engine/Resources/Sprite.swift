//
//  Sprite.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 24/08/2023.
//

import Foundation
import CoreGraphics
import AppKit


struct SpritePalette {
    var chunk: Array<UInt32>
    var start: UInt16
    var count: UInt16
}


struct SpriteAnimation {
    var x: Int16 = 0
    var y: Int16 = 0
    var width: UInt16 = 0
    var height: UInt16 = 0
    var definitionOffset: UInt32 = 0
    
    var frames: [SpriteAnimationFrame] = []
}


struct SpriteAnimationFrame {
    var groups: [SpriteAnimationImageGroup] = []
}


struct SpriteAnimationImageGroup {
    var offset: UInt32 = 0
    var images: [SpriteAnimationImage] = []
}


struct SpriteAnimationImage {
    var imageNumber: UInt16
    var xOffset: Int16
    var yOffset: Int16
}


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
    
    private var palette: [SpritePalette] = []
    private var alternatePalettes: [SpritePalette] = []

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
        
        if resource.fileName == "SHAI.HSQ" {
            self.parseShaiAnimations()
        } else if resource.fileName == "DEATH1.HSQ" {
            self.parseDeathAnimations()
        } else if resource.fileName == "ATTACK.HSQ" {
            // TODO: parse animations
        } else {
            /*if !self.parseAnimations() && !resource.stream!.isEOF() {
                self.parseAlternatePalettes()
            }*/
            
            if resource.fileName == "SUNRS.HSQ" || resource.fileName == "BALCON.HSQ" || resource.fileName == "SKY.HSQ" {
                self.parseAlternatePalettes()
            } else {
                self.parseAnimations()
            }
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
        
            palette.append(SpritePalette(chunk: paletteChunk, start: paletteStart, count: paletteCount))
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
                print("parseAlternatePalettes(): ERROR - header should be 0x0000")
                break
            }
            
            resource.stream!.skip(2)
            
            let chunkSize = resource.stream!.readUInt16LE()

            if chunkSize <= 2 {
                print("parseAlternatePalettes(): ERROR - invalid chunk size")
                break
            }

            let paletteStart = UInt16(resource.stream!.readByte())
            let paletteCount = UInt16(resource.stream!.readByte())
            
            if chunkSize - 2 != paletteCount * 3 {
                print("parseAlternatePalettes(): not a palette part")
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
        
            alternatePalettes.append(SpritePalette(chunk: paletteChunk, start: paletteStart, count: paletteCount))
        }
        
        engine.logger.log(.debug, "parseAlternatePalettes(): END OF PARSING \(resource.fileName) -> \(resource.stream!.offset) = \(resource.stream!.size)")
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
                //print("parseFrames(): skipping frame=\(i), frameOffset=\(frameInfo.startOffset)")
                break
            }
            
            let w0 = resource.stream!.readUInt16LE()
            let w1 = resource.stream!.readUInt16LE()

            let flags = UInt8((w0 & 0xFF00) >> 8)
            let width = UInt16(w0 & 0x7FFF)
            let height = UInt16(w1 & 0x00FF)
            let paletteOffset = UInt8((w1 & 0xFF00) >> 8)
            let isCompressed = (flags & 0x80) > 0

            //print("parseFrames(): frame=\(i), frameOffset=\(frameStartOffset), width=\(width), height=\(height), flags=\(String.fromByte(flags)) compressed=\(isCompressed ? "YES" : "NO")")

            var bytesPerRow = (width + 1) / 2

            // Re-add 1 to transform an odd number of pixels to read into an even number of pixels to read.
            if bytesPerRow % 2 == 1 {
                bytesPerRow += 1
            }

            let frameInfo = SpriteFrameInfo(2 * Int(width) * Int(height))
            frameInfo.startOffset = frameStartOffset
            frameInfo.isCompressed = isCompressed
            frameInfo.bytesPerRow = bytesPerRow
            frameInfo.width = width
            frameInfo.height = height
            frameInfo.paletteOffset = paletteOffset
         
            // Skip 4 bytes of frame header to access the pixels
            resource.stream!.seek(frameInfo.startOffset + 4)
            
            if !frameInfo.isCompressed {
                compute4bpp(frameInfo)
            } else {
                compute4bppRLE(frameInfo)
            }

            frames.append(frameInfo)
        }
        
        animationOffset = resource.stream!.offset
                
        setPalette()
        
        print("parseFrames(): finished reading. resource size=\(resource.stream!.size), anim offset=\(animationOffset)")
    }
    
    
    func frame(at index: Int) -> SpriteFrameInfo {
        return frames[index]
    }

    
    func animation(at index: Int) -> SpriteAnimation {
        return animations[index]
    }

    
    func parseAnimations() -> Bool {
        if animationOffset >= resource.stream!.size - 2 {
            // No animations found
            return false
        }
        
        // Find starting position for anims
        resource.stream!.seek(animationOffset)
        
        // let animationSize = resource.stream!.size - animationOffset

        // Read header (should be 0x0000)
        let animationHeaderSize: UInt32 = 14
        let header = resource.stream!.readUInt16()
        
        if (header != 0x0000) {
            engine.logger.log(.error, "parseAnimations(): ERROR - header=0x0000")
            // No animation found
            resource.stream!.seek(animationOffset)
            return false
        }
        
        let blockSize = resource.stream!.readUInt16LE() // Block size
        
        if animationOffset + UInt32(blockSize) > resource.stream!.size {
            engine.logger.log(.error, "parseAnimations(): ERROR - Offset and size are above the resource size. animationOffset=\(animationOffset), blockSize=\(blockSize), resourceSize=\(resource.stream!.size)")
            resource.stream!.seek(animationOffset)
            return false
        }
        
        let animX = resource.stream!.readUInt16LE()
        
        if animX > 320 {
            engine.logger.log(.error, "parseAnimations(): ERROR - animX > 320. Something was not parsed correctly")
            resource.stream!.seek(animationOffset)
            return false
        }
        
        let animY = resource.stream!.readUInt16LE()
        let animWidth = resource.stream!.readUInt16LE()
        let animHeight = resource.stream!.readUInt16LE()
        let animDefinitionOffset = UInt32(resource.stream!.readUInt16LE())
        
        engine.logger.log(.debug, "Animation header: size=\(blockSize), x=\(animX), y=\(animY), width=\(animWidth), height=\(animHeight), offset=\(animDefinitionOffset)")
        
        // Reads the first image group def: this is the size of image group header
        let imageGroupSize = resource.stream!.readUInt16LE(peek: true) / 2
        var imageGroupIndex: [UInt16] = []

        for _ in 0..<imageGroupSize - 1 {
            imageGroupIndex.append(resource.stream!.readUInt16LE())
        }
        
        var imageGroups: [SpriteAnimationImageGroup] = []

        for i: Int in 0..<imageGroupIndex.count {
            var group = SpriteAnimationImageGroup()
            group.offset = UInt32(imageGroupIndex[i])

            resource.stream!.seek(animationOffset + animationHeaderSize + group.offset)
            
            // Add image reference in group whil byte until we meet 0x00 marking end of image group
            while resource.stream!.readByte(peek: true) != 0 {
                let bytes = resource.stream!.readBytes(3)
                let groupImage = SpriteAnimationImage(
                    imageNumber: UInt16(bytes[0] - 1),
                    xOffset: Int16(bytes[1]),
                    yOffset: Int16(bytes[2])
                )
                
                group.images.append(groupImage)
            }
            
            resource.stream?.skip(1) // 0x00
            imageGroups.append(group)
        }

        // Animation groups
        resource.stream!.seek(animationOffset + animationHeaderSize + animDefinitionOffset - 2)
        
        let animGroupOffset = resource.stream!.offset
        var animGroupIndex: [UInt16] = []

        while animGroupIndex.isEmpty || (animGroupIndex.last! < resource.stream!.readUInt16LE(peek: true) && resource.stream!.readUInt16LE(peek: true) & 0xFF00 == 0) {
            animGroupIndex.append(resource.stream!.readUInt16LE())
        }

        for i: Int in 0..<animGroupIndex.count {
            var animation = SpriteAnimation(
                x: Int16(animX),
                y: Int16(animY),
                width: animWidth,
                height: animHeight,
                definitionOffset: animDefinitionOffset
            )
            
            resource.stream!.seek(animGroupOffset + UInt32(animGroupIndex[i]))
            
            var animationFrame = SpriteAnimationFrame()
            
            while !resource.stream!.isEOF() && resource.stream!.readByte(peek: true) != 0xFF {
                let byteValue = resource.stream!.readByte()
                
                if byteValue == 0x00 {
                    animation.frames.append(animationFrame)
                    animationFrame = SpriteAnimationFrame()
                    continue
                }
                
                // Group indexes start at 02
                
                let groupIndex = min(Int(byteValue - 2), imageGroups.count - 1)
                animationFrame.groups.append(imageGroups[groupIndex])
            }

            resource.stream!.skip(1) // 0xFF
            
            if animationFrame.groups.count > 0 {
                animation.frames.append(animationFrame)
            }
            
            animations.append(animation)
        }
        
        return true
    }
    
    
    func parseShaiAnimations() {
        resource.stream!.seek(animationOffset)
        
        engine.logger.log(.debug, "parseShaiAnimations(): offset=\(animationOffset), size=\(resource.stream!.size)")
        
        // Find starting position for anims
        resource.stream!.seek(animationOffset)
        
        // let animationSize = resource.stream!.size - animationOffset

        // Read header (should be 0x0000)
        // let animationHeaderSize: UInt32 = 14
        let header = resource.stream!.readUInt16()
        
        if (header != 0x0000) {
            engine.logger.log(.error, "parseShaiAnimations(): ERROR - header=0x0000")
            // No animation found
            return
        }
        
        let blockSize = resource.stream!.readUInt16LE() // Block size
        
        if animationOffset + UInt32(blockSize) > resource.stream!.size {
            engine.logger.log(.error, "parseShaiAnimations(): ERROR - Offset and size are above the resource size. animationOffset=\(animationOffset), blockSize=\(blockSize), resourceSize=\(resource.stream!.size)")
            return
        }

        var animation = SpriteAnimation()
        animation.x = 0
        animation.y = 0
        animation.width = 320
        animation.height = 200
        animation.definitionOffset = animationOffset
        
        var maxSpriteIndex: UInt16 = 0
        var group = SpriteAnimationImageGroup()
        
        while !resource.stream!.isEOF() {
            if resource.stream!.offset < resource.stream!.size - 8 {
                let x1 = resource.stream!.readUInt16LE()
                let y1 = resource.stream!.readUInt16LE()
                let x2 = resource.stream!.readUInt16LE()
                let y2 = resource.stream!.readUInt16LE()

                // Blit region to clear previous sprite
                if x1 < x2 && y1 < y2 && x1 != maxSpriteIndex + 1 {
                    var frame = SpriteAnimationFrame()
                    frame.groups.append(group)
                    animation.frames.append(frame)

                    group = SpriteAnimationImageGroup()
                    continue
                }
             
                resource.stream!.seek(resource.stream!.offset - 8)
            }
            
            let spriteIndex = resource.stream!.readUInt16LE()
            let x = resource.stream!.readUInt16LE()
            let y = resource.stream!.readUInt16LE()
            
            maxSpriteIndex = spriteIndex
            
            let groupImage = SpriteAnimationImage(
                imageNumber: UInt16(spriteIndex),
                xOffset: Int16(x),
                yOffset: Int16(y)
            )
            
            group.images.append(groupImage)
        }

        var frame = SpriteAnimationFrame()
        frame.groups.append(group)
        animation.frames.append(frame)

        animations.append(animation)
    }
    
    
    func parseDeathAnimations() {
        resource.stream!.seek(animationOffset)
        
        engine.logger.log(.debug, "parseDeathAnimations(): offset=\(animationOffset), size=\(resource.stream!.size)")
        
        // Find starting position for anims
        resource.stream!.seek(animationOffset)
        
        // let animationSize = resource.stream!.size - animationOffset

        // Read header (should be 0x0000)
        // let animationHeaderSize: UInt32 = 14
        let header = resource.stream!.readUInt16()
        
        if (header != 0x0000) {
            engine.logger.log(.error, "parseDeathAnimations(): ERROR - header=0x0000")
            // No animation found
            return
        }
        
        let blockSize = resource.stream!.readUInt16LE() // Block size
        
        if animationOffset + UInt32(blockSize) > resource.stream!.size {
            engine.logger.log(.error, "parseDeathAnimations(): ERROR - Offset and size are above the resource size. animationOffset=\(animationOffset), blockSize=\(blockSize), resourceSize=\(resource.stream!.size)")
            return
        }

        var animation = SpriteAnimation()
        animation.x = 0
        animation.y = 0
        animation.width = 320
        animation.height = 200
        animation.definitionOffset = animationOffset
        
        var group = SpriteAnimationImageGroup()
        
        while !resource.stream!.isEOF() {
            // End of frame
            if resource.stream!.readUInt16LE(peek: true) == 0xFFFF {
                var frame = SpriteAnimationFrame()
                frame.groups.append(group)
                animation.frames.append(frame)

                group = SpriteAnimationImageGroup()
                
                resource.stream!.skip(2)
                continue
            }
            
            let spriteIndex = resource.stream!.readUInt16LE()
            let x = resource.stream!.readUInt16LE()
            let y = resource.stream!.readUInt16LE()
            
            let groupImage = SpriteAnimationImage(
                imageNumber: UInt16(spriteIndex),
                xOffset: Int16(x),
                yOffset: Int16(y)
            )
            
            print("parseDeathAnimations(): frame=\(animation.frames.count), index=\(spriteIndex), x=\(x), y=\(y)")
            
            group.images.append(groupImage)
        }

        var frame = SpriteAnimationFrame()
        frame.groups.append(group)
        animation.frames.append(frame)

        animations.append(animation)
    }
    
    
    func loadAnimation(_ index: UInt16) {
        guard index < animations.count else {
            engine.logger.log(.error, "Invalid animation index: \(index)")
            return
        }
        
        self.currentAnimationIndex = index
        self.currentAnimationFrameIndex = 0
    }
    
    
    func setAnimationFrame(_ frameIndex: UInt16) {
        self.currentAnimationFrameIndex = frameIndex
    }
    
    
    func nextAnimationFrame(buffer: PixelBuffer) {
        let currentAnimation = self.animations[Int(self.currentAnimationIndex)]
        self.drawAnimation(self.currentAnimationIndex, buffer: buffer, time: Double(self.currentAnimationFrameIndex) * (1.0 / animationFrameRate))

        self.currentAnimationFrameIndex = (self.currentAnimationFrameIndex + 1) % UInt16(currentAnimation.frames.count)
    }
    
    
    func drawAnimation(_ animIndex: UInt16, buffer: PixelBuffer, time: Double = 0.0, offset: DunePoint = .zero) {
        guard animIndex < animations.count else {
            engine.logger.log(.error, "Invalid animation index: \(animIndex)")
            return
        }

        let animation = animations[Int(animIndex)]
        
        let frameIndex = Int(time / (1.0 / animationFrameRate)) % animation.frames.count
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
        
        for effect in effects {
            switch effect {
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

            while i < maxX2 {
                let srcIndex = Int(CGFloat(j - y1) / scaleRatio) * scaledFrameWidth + Int(CGFloat(i - x1) / scaleRatio)
                var paletteIndex = frameInfo.paletteIndices[srcIndex]

                if paletteIndex <= frameInfo.paletteOffset || paletteIndex == 0 {
                    i += 1
                    continue
                }
                
                paletteIndex = UInt8(Int(paletteIndex) + roomPaletteOffset)

                let x = flipX ? x2 - (i - x1) - 1 : i
                let y = flipY ? y2 - (j - y1) - 1 : j
                
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
            
            while lineRemain > 0 {
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
            }
            
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
