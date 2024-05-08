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


struct SpriteFrameInfo {
    var startOffset: UInt32 = 0
    var isCompressed: Bool = false
    var realWidth: UInt16 = 0
    var width: UInt16 = 0
    var height: UInt16 = 0
    var bytesPerRow: UInt16 = 0
    var paletteOffset: UInt8 = 0
    var paletteIndices: ContiguousArray<Int> = []
}

final class Sprite: Equatable {
    static func == (lhs: Sprite, rhs: Sprite) -> Bool {
        return lhs.resource.fileName == rhs.resource.fileName
    }
    
    
    private var engine: DuneEngine
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
        self.engine = DuneEngine.shared
        
        self.parsePalette()
        self.parseFrames()
        
        if resource.fileName == "SHAI.HSQ" || resource.fileName == "ATTACK.HSQ" || resource.fileName == "DEATH1.HSQ" {
            self.parseAlternateAnimations()
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
            
            for i: UInt16 in 0..<paletteCount {
                if i + paletteStart > 256 {
                    break
                }
                
                let r = UInt32(resource.stream!.readByte() << 2)
                let g = UInt32(resource.stream!.readByte() << 2)
                let b = UInt32(resource.stream!.readByte() << 2)
                let a = UInt32(0xFF)
                
                paletteChunk[Int(i)] = (a << 24) | (b << 16) | (g << 8) | r
            }
        
            alternatePalettes.append(SpritePalette(chunk: paletteChunk, start: paletteStart, count: paletteCount))
        }
        
        print("parseAlternatePalettes(): END OF PARSING \(resource.fileName) -> \(resource.stream!.offset) = \(resource.stream!.size)")
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
            
            var frameInfo = SpriteFrameInfo()
            let frameStartOffset = frameIndexOffset + frameOffset
            frameInfo.startOffset = frameStartOffset
            
            resource.stream!.seek(frameInfo.startOffset)

            // If two first bytes are 0x0000 we are looking at something else than an image part
            if resource.stream!.readUInt16LE(peek: true) == 0x0000 {
                //print("parseFrames(): skipping frame=\(i), frameOffset=\(frameInfo.startOffset)")
                break
            }
            
            let widthAndCompression = resource.stream!.readUInt16LE()

            frameInfo.isCompressed = (widthAndCompression & 0x8000) > 0
            
            var width = UInt16(widthAndCompression & 0x7FFF)
            let height = UInt16(resource.stream!.readByte())
            let paletteOffset = resource.stream!.readByte()
            
            let realWidth = width
            
            if width > 0 {
                width += (4 - width % 4) % 4
            }

            //print("parseFrames(): frame=\(i), frameOffset=\(frameInfo.startOffset), width=\(width), height=\(height), compressed=\(frameInfo.isCompressed ? "YES" : "NO")")

            var bytesPerRow = (width + 1) / 2

            // Re-add 1 to transform an odd number of pixels to read into an even number of pixels to read.
            if bytesPerRow % 2 == 1 {
                bytesPerRow += 1
            }

            frameInfo.bytesPerRow = bytesPerRow
            frameInfo.realWidth = realWidth
            frameInfo.width = width
            frameInfo.height = height
            frameInfo.paletteIndices = ContiguousArray<Int>(repeating: 0, count: Int(width) * Int(height))
            frameInfo.paletteOffset = paletteOffset
            
            frames.append(frameInfo)
        }
        
        let lastFrameInfo = frames.last!
        let totalSize = UInt32(lastFrameInfo.bytesPerRow * 2) * UInt32(lastFrameInfo.height)

        resource.stream!.seek(lastFrameInfo.startOffset + 4)

        if !lastFrameInfo.isCompressed {
            animationOffset = resource.stream!.offset + (totalSize / 2)
        } else {
            var current: UInt32 = 0
            
            while current < totalSize {
                let repetition = Int16(resource.stream!.readSByte())
                
                let count = Int(abs(repetition) + 1)
                let _ = repetition < 0 ? resource.stream!.readByte() : 0
                
                for _ in 0..<count {
                    if repetition >= 0 {
                        let _ = resource.stream!.readByte()
                    }
                    
                    current += 1
                    
                    if (current == totalSize) {
                        break
                    }

                    current += 1
                    
                    if (current == totalSize) {
                        break
                    }
                }
            }
            
            animationOffset = resource.stream!.offset
        }
                
        setPalette()
        
        for i in 0..<Int(frames.count) {
            let frameInfo = frames[i]
            
            frames[i].paletteIndices.withUnsafeMutableBytes { ptr in
                let intPtr = ptr.bindMemory(to: Int.self)
                computeFramePixels(frameInfo, buffer: intPtr.baseAddress!)
            }
        }
        
        //print("parseFrames(): finished reading. resource size=\(resource.stream!.size), anim offset=\(animationOffset)")
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
        
        let animationSize = resource.stream!.size - animationOffset

        // Read header (should be 0x0000)
        let animationHeaderSize: UInt32 = 14
        let header = resource.stream!.readUInt16()
        
        if (header != 0x0000) {
            print("parseAnimations(): ERROR - header=0x0000")
            // No animation found
            resource.stream!.seek(animationOffset)
            return false
        }
        
        let blockSize = resource.stream!.readUInt16LE() // Block size
        
        if animationOffset + UInt32(blockSize) > resource.stream!.size {
            print("parseAnimations(): ERROR - Offset and size are above the resource size. animationOffset=\(animationOffset), blockSize=\(blockSize), resourceSize=\(resource.stream!.size)")
            resource.stream!.seek(animationOffset)
            return false
        }
        
        let animX = resource.stream!.readUInt16LE()
        
        if animX > 320 {
            print("parseAnimations(): ERROR - animX > 320. Something was not parsed correctly")
            resource.stream!.seek(animationOffset)
            return false
        }
        
        let animY = resource.stream!.readUInt16LE()
        let animWidth = resource.stream!.readUInt16LE()
        let animHeight = resource.stream!.readUInt16LE()
        let animDefinitionOffset = UInt32(resource.stream!.readUInt16LE())
        
        print("Animation header: size=\(blockSize), x=\(animX), y=\(animY), width=\(animWidth), height=\(animHeight), offset=\(animDefinitionOffset)")
        
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
    
    
    func parseAlternateAnimations() {
        resource.stream!.seek(animationOffset)
        
        print("parseAlternateAnimations(): offset=\(animationOffset), size=\(resource.stream!.size)")

        if animationOffset >= resource.stream!.size - 2 {
            // No animations found
            return
        }
        
        // Find starting position for anims
        resource.stream!.seek(animationOffset)
        
        let animationSize = resource.stream!.size - animationOffset

        // Read header (should be 0x0000)
        let animationHeaderSize: UInt32 = 14
        let header = resource.stream!.readUInt16()
        
        if (header != 0x0000) {
            print("parseAlternateAnimations(): ERROR - header=0x0000")
            // No animation found
            return
        }
        
        let blockSize = resource.stream!.readUInt16LE() // Block size
        
        if animationOffset + UInt32(blockSize) > resource.stream!.size {
            print("parseAlternateAnimations(): ERROR - Offset and size are above the resource size. animationOffset=\(animationOffset), blockSize=\(blockSize), resourceSize=\(resource.stream!.size)")
            return
        }
    }
    
    
    func loadAnimation(_ index: UInt16) {
        guard index < animations.count else {
            print("Invalid animation index: \(index)")
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
            print("Invalid animation index: \(animIndex)")
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
        let bufferWidth = buffer.width
        let bufferHeight = buffer.height
        
        let frameInfo = frames[Int(index)]
        var alignedFrameWidth = Int(frameInfo.width)
        var frameWidth = Int(frameInfo.realWidth)
        var frameHeight = Int(frameInfo.height)
        var roomPaletteOffset = 0
        let scaledFrameWidth = alignedFrameWidth
        
        // Effects
        var opacity = 1.0
        var flipX = false
        var flipY = false
        var scaleRatio = 1.0
        
        switch effect {
        case .fadeIn(let start, let duration, let current):
            let progress = (current - start) / duration
            opacity = Math.clampf(progress, 0.0, 1.0)
            break
        case .fadeOut(let end, let duration, let current):
            let progress = (end - current) / duration
            opacity = Math.clampf(progress, 0.0, 1.0)
            break
        case .transform(let offset, let flipHorizontal, let flipVertical, let scaleFactor):
            flipX = flipHorizontal
            flipY = flipVertical
            roomPaletteOffset = offset != 0 ? Int(offset) - Int(frameInfo.paletteOffset) : 0
            
            if scaleFactor != 1.0 {
                scaleRatio = scaleFactor
                alignedFrameWidth = Int(Double(alignedFrameWidth) * scaleRatio)
                frameWidth = Int(Double(frameWidth) * scaleRatio)
                frameHeight = Int(Double(frameHeight) * scaleRatio)
            }

            break
        default:
            opacity = 1.0
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

        let opacityMask = (UInt32(255.0 * Math.clampf(opacity, 0.0, 1.0)) << 24) | 0x00FFFFFF
        
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
                
                paletteIndex += roomPaletteOffset

                let x = flipX ? x2 - (i - x1) - 1 : i
                let y = flipY ? y2 - (j - y1) - 1 : j
                
                let destIndex = y * bufferWidth + x
                
                if (engine.palette.rawPointer[paletteIndex] >> 24) == 0x00 {
                    i += 1
                    continue
                }
                
                buffer.rawPointer[destIndex] = engine.palette.rawPointer[paletteIndex] & opacityMask

                i += 1
            }
            
            j += 1
        }
    }
    
    
    private func computeFramePixels(_ frameInfo: SpriteFrameInfo, buffer: UnsafeMutablePointer<Int>) {
        // Skip 4 bytes of frame header to access the pixels
        resource.stream!.seek(frameInfo.startOffset + 4)
        
        let totalSize = UInt32(frameInfo.bytesPerRow * 2) * UInt32(frameInfo.height)
        var current: UInt32 = 0
        
        func getIndex(_ pt: UInt32) -> Int {
            let dx = Int(pt % UInt32(frameInfo.bytesPerRow * 2))
            let dy = Int(pt / UInt32(frameInfo.bytesPerRow * 2))
            
            return (dy * Int(frameInfo.width)) + dx
        }
        
        
        var pixel: UInt8 = 0
        var count: Int = 0
        let paletteOffset = Int(frameInfo.paletteOffset)

        if !frameInfo.isCompressed {
            let resourceBuffer = resource.stream!.readBytes(totalSize / 2)

            while current < totalSize {
                pixel = resourceBuffer[Int(current / 2)]
                
                let paletteIndex1 = Int(pixel & 0xf) + paletteOffset
                let index1 = getIndex(current)
                
                buffer[index1] = paletteIndex1
                current += 1
                
                if current >= totalSize {
                    break
                }
                
                let paletteIndex2 = Int(pixel >> 4) + paletteOffset
                let index2 = getIndex(current)

                buffer[index2] = paletteIndex2
                current += 1
                
                if current >= totalSize {
                    break
                }
            }
        } else {
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
                    
                    let paletteIndex1 = Int(pixel & 0xf) + paletteOffset
                    let index1 = getIndex(current)
                    buffer[index1] = paletteIndex1
                    
                    current += 1
                    
                    if current >= totalSize {
                        break
                    }
                    
                    let paletteIndex2 = Int(pixel >> 4) + paletteOffset
                    let index2 = getIndex(current)

                    buffer[index2] = paletteIndex2
                    current += 1
                    
                    if current >= totalSize {
                        break
                    }
                    
                    n += 1
                }
            }
        }
    }
    
    
    func debugBytes(_ byteCount: UInt32) {
        let bytes = resource.stream!.readBytes(byteCount, peek: true)
        print("\(byteCount) BYTES: \(bytes.map { String.fromByte($0) })")
    }
    
    
    func dumpInfo() throws {
        print("------")
        print("Sprite name: \(resource.fileName)")
        print("Frame count: \(frames.count)")
        
        for i in 0..<frames.count {
            print("Frame #\(i): width=\(frames[i].width), height=\(frames[i].height), compressed=\(frames[i].isCompressed ? "YES": "NO"), paletteOffset=\(frames[i].paletteOffset)")
        }
        
        print("")
        print("Animation count: \(animations.count)")
        
        for i in 0..<animations.count {
            print("Animation #\(i): width=\(animations[i].width), height=\(animations[i].height), frames=\(animations[i].frames.count)")
            
            for j in 0..<animations[i].frames.count {
                let frame = animations[i].frames[j]

                print("- Frame #\(j): groups=\(frame.groups.count)")
                
                for k in 0..<frame.groups.count {
                    let group = frame.groups[k]

                    print("  - Group #\(k): images=\(group.images.count)")
                    
                    for l in 0..<group.images.count {
                        print("    - Image #\(l): frame=\(group.images[l].imageNumber), x=\(group.images[l].xOffset), y=\(group.images[l].yOffset)")
                    }
                }
            }
        }
        
        print("------")
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
