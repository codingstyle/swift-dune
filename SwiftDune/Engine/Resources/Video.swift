//
//  Video.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 21/08/2023.
//

// @see https://github.com/OpenRakis/OpenRakis/blob/master/src/openrakis/scummvm/video.cpp
// @see https://wiki.multimedia.cx/index.php?title=HNM_(1)

import Foundation

enum VideoTwoCC: UInt16 {
    case pl = 0x6C70 // Palette
    case sd = 0x6473 // Sound
    case mm = 0x6D6D // ?
    case kl = 0x6C6B // ? (Collision map)
    case pt = 0x7470 // ? (Game related)
}

struct VideoPalette {
    var chunk: Array<UInt32>
    var start: UInt16
    var count: UInt16
}

struct PaletteBlock {
    var paletteChunks: [VideoPalette]
    
    private func dumpInfo() {
    }
}

struct VideoBlock {
    var x: UInt16
    var y: UInt16
    var width: UInt16
    var height: UInt8
    var flags: UInt8
    var mode: UInt8
    var sum: UInt8
    var uncompressedBytesCount: Int
    var uncompressedBytesPointer: UnsafeMutableRawPointer?
    
    func dumpInfo() {
        print("Video Block:")
        print("- Checksum: \(sum)")
        print("- Video offset: \(x), \(y)")
        print("- Video width: \(width)")
        print("- Video height: \(height)")
        print("- Video mode: \(String.fromByte(mode))")
        print("- Video flags: \(String.fromByte(flags))")
        print("- Uncompressed actual size: \(uncompressedBytesCount)")
    }
}

struct VideoFrame {
    var paletteBlock: PaletteBlock?
    var videoBlock: VideoBlock?
}

struct VideoHeader {
    var headerSize: UInt16
    var palette: [VideoPalette]
    
    func dumpInfo() {
        print("Video header:")
        print("- Header size=\(headerSize)")
        //print("- Palette=\(palette)")
    }
}

final class Video {
    private var engine: DuneEngine
    private var resource: Resource
    private var videoHeader: VideoHeader?
    private var frames: [VideoFrame] = []
    private var currentFrameIndex = 0

    private let frameRate = 15.0

    init(_ fileName: String, engine: DuneEngine) {
        self.engine = engine
        self.resource = Resource(fileName, uncompressed: true)

        parseHeader()
        parseSuperchunks()
    }
    
    deinit {
        for frame in frames {
            if let videoBlock = frame.videoBlock,
               let ptr = videoBlock.uncompressedBytesPointer {
                ptr.deallocate()
            }
        }
    }
    
    
    private func parseHeader() {
        let headerSize = resource.stream!.readUInt16LE()

        // Initial palette block
        let paletteBlock = parsePaletteBlock(UInt32(headerSize))
        
        // Skip bytes of padding (0xFF)
        while resource.stream!.readByte(peek: true) == 0xFF {
            resource.stream!.skip(1)
        }
        
        videoHeader = VideoHeader(headerSize: headerSize, palette: paletteBlock.paletteChunks)
        videoHeader?.dumpInfo()

        resource.stream!.seek(UInt32(headerSize))
    }

    
    func setPalette() {
        for var paletteChunk in videoHeader!.palette {
            engine.palette.update(&paletteChunk.chunk, start: paletteChunk.start, count: paletteChunk.count)
        }
    }

    
    private func parseSuperchunks() {
        while !resource.stream!.isEOF() {
            let startOffset = UInt32(resource.stream!.offset)
            let superchunkSize = UInt32(resource.stream!.readUInt16LE())
            let endSuperchunkOffset = startOffset + superchunkSize
            engine.logger.log(.debug, "Super chunk size: \(superchunkSize)")
            
            var videoFrame = VideoFrame()
            
            while resource.stream!.offset < endSuperchunkOffset {
                let chunkTag = resource.stream!.readUInt16LE(peek: true)

                engine.logger.log(.debug, "-----------------")

                if chunkTag == VideoTwoCC.pl.rawValue {
                    engine.logger.log(.debug, "PL ->")
                    let paletteBlock = parsePaletteBlock(resource.stream!.size)
                    videoFrame.paletteBlock = paletteBlock
                } else if chunkTag == VideoTwoCC.sd.rawValue {
                    engine.logger.log(.debug, "SD ->")
                    parseSoundBlock()
                } else if chunkTag == VideoTwoCC.mm.rawValue {
                    engine.logger.log(.debug, "MM ->")
                    let size = UInt32(resource.stream!.readUInt16LE())
                    resource.stream!.skip(size - 4)
                } else {
                    let videoBlock = parseVideoBlock(superchunkSize)
                    videoFrame.videoBlock = videoBlock
                }
            }
            
            frames.append(videoFrame)
        }
    }
    
    
    private func parsePaletteBlock(_ limitOffset: UInt32) -> PaletteBlock {
        var paletteChunks: [VideoPalette] = []

        while resource.stream!.offset < limitOffset {
            let h = resource.stream!.readUInt16LE()
            
            // 0x0100 marks a 3 byte leap
            if h == 0x0100 {
                resource.stream!.skip(3)
                continue
            }
            
            // 0xFFFF marks the end of palette block
            if h == 0xFFFF {
                break
            }
            
            var paletteCount = (h >> 8)
            let paletteStart = (h & 0xFF)
            
            if paletteCount == 0x00 {
                paletteCount = 256
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
        
            paletteChunks.append(VideoPalette(chunk: paletteChunk, start: paletteStart, count: paletteCount))
        }
        
        let paletteBlock = PaletteBlock(paletteChunks: paletteChunks)
        return paletteBlock
    }
    
    
    private func parseSoundBlock() {
        // let chunkTag = resource.stream!.readUInt16()
        let chunkSize = UInt32(resource.stream!.readUInt16())

        resource.stream!.skip(chunkSize - 4)
    }
    
    
    private func parseVideoBlock(_ superchunkSize: UInt32) -> VideoBlock? {
        //let chunkTag = resource.stream!.readUInt16LE(peek: true)
        
        // Video
        let bytes = resource.stream!.readBytes(4)

        let width = ((0x1 & bytes[1]) << 8) | bytes[0]
        let flags = (bytes[1] & 0xFE)
        let height = bytes[2]
        let mode = bytes[3]
        //let bufferSize = superchunkSize - 6
        
        // Check hexa 82 00 00 82 00 FF?

        // Width or height at zero means we repeat previous frame
        if width == 0 || height == 0 {
            engine.logger.log(.debug, "VIDEO -> Repeat previous frame")
            return nil
        }

        // Verify checksum
        let videoHeaderBytes = resource.stream!.readBytes(6, peek: true)
        let checksum = UInt8(videoHeaderBytes.reduce(0, { Int($0) + Int($1) }) & 0xFF)
        
        if checksum != 0xAB && checksum != 0xAC && checksum != 0xAD {
            return nil
        }

        engine.logger.log(.debug, "parseVideoBlock(): checksum=\(checksum), mode=\(mode)")

        let uncompressedSize = resource.stream!.readUInt16LE()
        let _ = resource.stream!.readByte() // Should be zero
        let compressedSize = resource.stream!.readUInt16LE()
        let _ = resource.stream!.readByte() // Salt

        let compressedBytes = resource.stream!.readBytes(UInt32(compressedSize) - 6)
        let frameStream = ResourceStream(compressedBytes)
        var uncompressedBytes = unpackHSQ(frameStream)
        
        var x: UInt16 = 0
        var y: UInt16 = 0
        
        if flags & 0x04 == 0 {
            x = UInt16(uncompressedBytes[1]) << 8 | UInt16(uncompressedBytes[0])
            y = UInt16(uncompressedBytes[3]) << 8 | UInt16(uncompressedBytes[2])
            uncompressedBytes = Array(uncompressedBytes[4..<Int(uncompressedSize)])
        }
        
        let videoBlock = VideoBlock(
            x: x,
            y: y,
            width: UInt16(width),
            height: height,
            flags: flags,
            mode: mode,
            sum: checksum,
            uncompressedBytesCount: uncompressedBytes.count,
            uncompressedBytesPointer: UnsafeMutableRawPointer.allocate(byteCount: uncompressedBytes.count, alignment: 1)
        )
        
        let _ = memcpy(videoBlock.uncompressedBytesPointer!, &uncompressedBytes, uncompressedBytes.count)
        return videoBlock
    }
    
    
    public func hasFrames() -> Bool {
        return currentFrameIndex < frames.count
    }
    
    
    public func isFrameEmpty() -> Bool {
        if !hasFrames() {
            return true
        }
        
        let currentFrame = frames[currentFrameIndex]        
        return currentFrame.videoBlock == nil
    }
    

    public func moveToNextFrame() {
        currentFrameIndex += 1
    }
    
    public func setTime(_ time: Double) {
        currentFrameIndex = Int(time / (1.0 / frameRate))
    }
        
    public func renderFrame(_ buffer: PixelBuffer, flipX: Bool = false, flipY: Bool = false) {
        if !hasFrames() {
            return
        }
        
        let currentFrame = frames[currentFrameIndex]
        
        if let paletteBlock = currentFrame.paletteBlock {
            for var paletteChunk in paletteBlock.paletteChunks {
                engine.palette.update(&paletteChunk.chunk, start: paletteChunk.start, count: paletteChunk.count)
            }
        }
        
        guard let videoBlock = currentFrame.videoBlock else {
            //print("Video: Nothing to render for frame: #\(currentFrameIndex)")
            return
        }
        
        let frameWidth = Int(videoBlock.width)
        let frameHeight = Int(videoBlock.height)
        let frameX = Int(videoBlock.x)
        let frameY = Int(videoBlock.y)
        
        var srcIndex = 0
        var destX = 0
        var destY = 0
        var destIndex = 0
        
        let videoFrameByteCount = videoBlock.uncompressedBytesCount
        var paletteIndex: UInt8 = 0
        
        var j = 0

        while j < frameHeight {
            var i = 0

            while i < frameWidth {
                srcIndex = j * frameWidth + i
                
                if srcIndex >= videoFrameByteCount {
                    break
                }
                                
                paletteIndex = videoBlock.uncompressedBytesPointer!.load(fromByteOffset: srcIndex, as: UInt8.self)
                
                if paletteIndex == 0x00 {
                    i += 1
                    continue
                }

                destX = flipX ? 319 - (frameX + i) : (frameX + i)
                destY = flipY ? 199 - (frameY + j) : (frameY + j)
                destIndex = destY * 320 + destX

                buffer.rawPointer[destIndex] = paletteIndex
                
                i += 1
            }
            
            j += 1
        }
    }
    
    
    /**
     * Unpacks HSQ content
     */
    private func unpackHSQ(_ stream: ResourceStream) -> [UInt8] {
        var queue: UInt16 = 0
        
        func readNextBit() -> UInt16 {
            var bit: UInt16 = queue & 1
            queue >>= 1
            
            if (queue == 0) {
                queue = stream.readUInt16LE()
                bit = queue & 1
                queue = 0x8000 | (queue >> 1)
            }

            return bit
        }
        
        // Read the two first bytes of instructions
        var count: UInt16 = 0
        var offset: Int16 = 0
        var unpackedData: [UInt8] = []
        
        while !stream.isEOF() {
            // Series of bits at 1 define the number of bytes to copy
            if readNextBit() == 1 {
                unpackedData.append(stream.readByte())
            } else {
                if readNextBit() == 1 {
                    let b0 = UInt16(stream.readByte())
                    let b1 = UInt16(stream.readByte())
                    
                    count = b0 & 0x7
                    offset = Int16((b0 >> 3) | (b1 << 5)) - 0x2000

                    if count == 0 {
                        count = UInt16(stream.readByte())
                    }
                             
                    // finish the unpacking
                    if count == 0 {
                        break
                    }
                } else {
                    count = readNextBit() * 2
                    count += readNextBit()
                    
                    let distance = stream.readByte()
                    offset = Int16(distance) - 256
                }

                count += 2

                let currentOffset = unpackedData.count
                let startCopy = Int(currentOffset) + Int(offset)
                let endCopy = startCopy + Int(count) - 1
                
                var i = startCopy
                
                while i <= endCopy {
                    unpackedData.append(unpackedData[i])
                    i += 1
                }
            }
        }
        
        return unpackedData
    }
}
