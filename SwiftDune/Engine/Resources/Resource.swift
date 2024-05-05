//
//  HSQAsset.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 21/08/2023.
//

import Foundation

// Original algorithm from:
// https://github.com/sonicpp/dunerevival-code/blob/scummvm-v1.9.0/cryo/resource.cpp#L153

enum ResourceType {
    /**
     Condition expressions for game logic
     */
    case gameLogic
    /**
     Fonts
     */
    case font
    /**
     Sprites
     */
    case sprite
    /**
     Files that don't have palette, so that palette effects can be done (ex: dune by day or by night)
     Load another sprite before to have a palette
     */
    case spriteWithoutPalette
    /**
     Sound effects
     Extension is HSQ but actually it is a Voice Creative (VOC) file
     */
    case sound
    /**
     Music
     - opl2 (adlib/soundblaster), in the *.HSQ files
     - opl3 (adlib gold only), in the *.AGD files
     - MT32 (roland mt-32?), in the *.M32 files
    */
    case music
    /**
     Full Motion Videos
     */
    case video
    /**
     Dialogue sentences
     */
    case sentence
    /**
     Rooms
     */
    case scene
    /**
     Globe
     */
    case globe
    
    var description: String {
        switch self {
        case .gameLogic: return "Game logic"
        case .font: return "Font"
        case .sprite: return "Sprite"
        case .spriteWithoutPalette: return "Sprite - No palette"
        case .sentence: return "Sentences"
        case .video: return "FMV"
        case .sound: return "Sound FX"
        case .music: return "Music"
        case .scene: return "Rooms"
        case .globe: return "Globe"
        }
    }
    
    var files: [String] {
        switch self {
        case .music:
            return [
                "ARRAKIS.AGD",
                "ARRAKIS.HSQ",
                "ARRAKIS.M32",
                "BAGDAD.AGD",
                "BAGDAD.HSQ",
                "BAGDAD.M32",
                "MORNING.AGD",
                "MORNING.HSQ",
                "MORNING.M32",
                "SEKENCE.AGD",
                "SEKENCE.HSQ",
                "SEKENCE.M32",
                "SIETCHM.AGD",
                "SIETCHM.HSQ",
                "SIETCHM.M32",
                "WARSONG.AGD",
                "WARSONG.HSQ",
                "WARSONG.M32",
                "WATER.AGD",
                "WATER.HSQ",
                "WATER.M32",
                "WORMINTR.AGD",
                "WORMINTR.HSQ",
                "WORMINTR.M32",
                "WORMSUIT.AGD",
                "WORMSUIT.HSQ",
                "WORMSUIT.M32"
            ]
        case .gameLogic:
            return [
                "CONDIT.HSQ",   // Game phases logic
                "DIALOGUE.HSQ", // Dialogue logic
                "VERBIN.HSQ",
                // TODO: Sound stuff?
                "DUNESDB.HSQ",
                "DUNEADL.HSQ",
                "DUNEADG.HSQ",
                "DUNEMID.HSQ",
                "DUNEPCS.HSQ",
                "DUNEVGA.HSQ",
            ]
        case .font:
            return [
                "DUNECHAR.HSQ", // In-game font
                "GENERIC.HSQ"   // End credits large font
            ]
        case .sound:
            return [
                "SD1.HSQ",
                "SD2.HSQ",
                "SD3.HSQ",
                "SD4.HSQ",
                "SD5.HSQ", // Note: SD5.HSQ is uncompressed.
                "SD6.HSQ",
                "SD7.HSQ",
                "SD8.HSQ",
                "SD9.HSQ",
                "SDA.HSQ",
                "SDB.HSQ",
            ]
        case .sentence:
            return [
                // English
                "PHRASE11.HSQ",
                "PHRASE12.HSQ",
                "COMMAND1.HSQ",
                // French
                "PHRASE21.HSQ",
                "PHRASE22.HSQ",
                "COMMAND2.HSQ",
                // German
                "PHRASE31.HSQ",
                "PHRASE32.HSQ",
                "COMMAND3.HSQ"
            ]
        case .scene:
            return [
                "VILG.SAL",
                "SIET.SAL",
                "PALACE.SAL",
                "HARK.SAL"
            ]
        case .spriteWithoutPalette:
            return [
                "DEATH2.HSQ",
                "DEATH3.HSQ",
                "DUNES.HSQ",
                "DUNES2.HSQ",
                "DUNES3.HSQ",
                "ICONES.HSQ",
                "PALPLAN.HSQ",
                "SHAI2.HSQ",
                "SIET0.HSQ"
            ]
        case .sprite:
            return [
                "ATTACK.HSQ",
                "BACK.HSQ",
                "BALCON.HSQ",
                "BARO.HSQ",
                "BOOK.HSQ",
                "BOTA.HSQ",
                "BUNK.HSQ",
                "CHAN.HSQ",
                "CHANKISS.HSQ",
                "COMM.HSQ",
                "CORR.HSQ",
                "CREDITS.HSQ",
                "CRYO.HSQ",
                "DEATH1.HSQ",
                "EMPR.HSQ",
                "EQUI.HSQ",
                "FEYD.HSQ",
                "FINAL.HSQ",
                "FORT.HSQ",
                "FRESK.HSQ",
                "FRM1.HSQ",
                "FRM2.HSQ",
                "FRM3.HSQ",
                "GURN.HSQ",
                "HARA.HSQ",
                "HARK.HSQ",
                "HAWA.HSQ",
                "IDAH.HSQ",
                "INTDS.HSQ",
                "JESS.HSQ",
                "KYNE.HSQ",
                "LETO.HSQ",
                "MIRROR.HSQ",
                "MOIS.HSQ",
                "ONMAP.HSQ",
                "ORNY.HSQ",
                "ORNYCAB.HSQ",
                "ORNYPAN.HSQ",
                "ORNYTK.HSQ",
                "PAUL.HSQ",
                "PERS.HSQ",
                "POR.HSQ",
                "PROUGE.HSQ",
                "SERRE.HSQ",
                "SHAI.HSQ",
                "SIET1.HSQ",
                "SKY.HSQ",
                "SMUG.HSQ",
                "STARS.HSQ",
                "STIL.HSQ",
                "SUN.HSQ",
                "SUNRS.HSQ",
                "VER.HSQ",
                "VILG.HSQ",
                "VIS.HSQ"                
            ]
            
        case .globe:
            return [
                "GLOBDATA.HSQ",
                "MAP.HSQ",
                "MAP2.HSQ",
            ]
            
        case .video:
            return [
                "LOGO.HNM",
                "PRT.HNM"
            ]
        }
    }
}

enum ResourceError: Error {
    case invalidFileName
    case checksumMismatch
    case fileSizeMismatch
}

struct ResourceHeader
{
    var isCompressed: UInt8?
    var uncompressedSize: UInt16?
    var compressedSize: UInt16?
    var data: Data?
    
    var checksumValue: UInt16 {
        guard let data = data else {
            return 0
        }
        
        let value = data.reduce(0) { (sum, byte) -> UInt16 in
            return sum + UInt16(byte)
        }
        
        let mask: UInt16 = 0xFF
        return value & mask
    }
}


class ResourceStream {
    var data: [UInt8] = []
    var offset: UInt32 = 0
    var size: UInt32 = 0
    
    init(_ data: [UInt8]) {
        self.data = data
        self.size = UInt32(truncatingIfNeeded: data.count)
    }
    
    func isEOF() -> Bool {
        return offset >= size
    }
    
    func seek(_ pos: UInt32) {
        offset = pos
    }
    
    func skip(_ count: UInt32) {
        offset += count
    }
    
    func readBytes(_ readSize: UInt32, peek: Bool = false) -> [UInt8] {
        let start = Int(offset)
        let end = Int(offset) + Int(readSize)

        let bytes = Array(data[start..<end])

        if !peek {
            offset += UInt32(readSize)
        }
        
        return bytes
    }
    
    func readByte(peek: Bool = false) -> UInt8 {
        if offset >= size {
            print("Trying to read offset \(offset) with size \(size)")
        }
        
        let b0 = data[Int(offset)]

        if !peek {
            offset += 1
        }

        return b0
    }

    func readSByte(peek: Bool = false) -> Int8 {
        let b0 = data[Int(offset)]
        
        if !peek {
            offset += 1
        }

        return Int8(bitPattern: b0)
    }
    

    func readUInt16(peek: Bool = false) -> UInt16 {
        let b0 = data[Int(offset)]
        let b1 = data[Int(offset) + 1]
        
        if !peek {
            offset += 2
        }
        
        let uint16Value = UInt16(b0) << 8 | UInt16(b1)
        return uint16Value
    }

    
    func readUInt16LE(peek: Bool = false) -> UInt16 {
        let b0 = data[Int(offset)]
        let b1 = data[Int(offset) + 1]
        
        if !peek {
            offset += 2
        }
        
        let uint16Value = UInt16(b1) << 8 | UInt16(b0)
        return uint16Value
    }
    
    
    func readUInt32(peek: Bool = false) -> UInt32 {
        let b0 = data[Int(offset)]
        let b1 = data[Int(offset) + 1]
        let b2 = data[Int(offset) + 2]
        let b3 = data[Int(offset) + 3]

        if !peek {
            offset += 4
        }
        
        let uint32Value = UInt32(b0) << 24 | UInt32(b1) << 16 | UInt32(b2) << 8 | UInt32(b3)
        return uint32Value
    }
    
    
    func readUInt32LE(peek: Bool = false) -> UInt32 {
        let b0 = data[Int(offset)]
        let b1 = data[Int(offset) + 1]
        let b2 = data[Int(offset) + 2]
        let b3 = data[Int(offset) + 3]

        if !peek {
            offset += 4
        }
        
        let uint32Value = UInt32(b3) << 24 | UInt32(b2) << 16 | UInt32(b1) << 8 | UInt32(b0)
        return uint32Value
    }
    
    
    func saveAs(_ fileName: String) {
        let downloadsDirectory = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        let fileURL = downloadsDirectory.appendingPathComponent(fileName)
        
        let dataToWrite = Data(data)
        
        do {
            try dataToWrite.write(to: fileURL)
            print("File saved successfully at: \(fileURL.path)")
        } catch {
            print("Error saving file: \(error.localizedDescription)")
        }
    }
}

/**
 Represents a HSQ file
 */
class Resource
{
    var unpackedData: [UInt8] = []
    var stream: ResourceStream?
    var fileName: String

    private static let validChecksum = 171

    private var fileSize: UInt64 = 0
    
    init(_ fileName: String, uncompressed: Bool = false) {
        self.fileName = fileName

        if uncompressed {
            self.parseRaw()
        } else {
            self.parseHSQ()
        }
    }
    
    
    func parseRaw() {
        let fileComponents = fileName.split(separator: ".")
        let fileNameWithoutExtension = String(fileComponents[0])
        let fileExtension = String(fileComponents[1])

        guard let filePath = Bundle.main.path(forResource: fileNameWithoutExtension, ofType: fileExtension, inDirectory: "DuneFiles") else {
            print("\(fileName): not found.")
            return
        }

        guard let fileHandle = FileHandle(forReadingAtPath: filePath) else {
            print("\(fileName): unable to read file.")
            return
        }

        defer {
            fileHandle.closeFile() // Make sure to close the file when done
        }
        
        do {
            let data = try fileHandle.readToEnd()
            unpackedData = [UInt8](data!)
            stream = ResourceStream(unpackedData)
        } catch {
            print("\(fileName): unable to read uncompressed file")
        }
    }
    
    
    func parseHSQ() {
        let fileComponents = fileName.split(separator: ".")
        
        guard fileComponents.count == 2 else {
            print("\(fileName): no extension found.")
            return
        }
                
        let fileExtension = String(fileComponents[1])
        
        guard fileExtension == "HSQ" || fileExtension == "SAL" else {
            print("\(fileExtension) is not a recognized HSQ format.")
            return
        }

        guard let filePath = Bundle.main.path(forResource: fileName.replacingOccurrences(of: ".\(fileExtension)", with: ""), ofType: fileExtension, inDirectory: "DuneFiles") else {
            print("\(fileName): not found.")
            return
        }

        guard let fileHandle = FileHandle(forReadingAtPath: filePath) else {
            print("\(fileName): unable to read file.")
            return
        }

        defer {
            fileHandle.closeFile() // Make sure to close the file when done
        }
        
        do {
            let header = try readHSQHeader(fileHandle)
            
            if header.checksumValue == Resource.validChecksum {
                unpackHSQ(fileHandle)
                stream = ResourceStream(unpackedData)
            } else {
                try fileHandle.seek(toOffset: 0)
                let data = try fileHandle.readToEnd()
                unpackedData = [UInt8](data!)
                stream = ResourceStream(unpackedData)
            }
        } catch {
            print("\(fileName): unable to decode file.")
            parseRaw()
        }
    }
    
    
    /**
     * Reads HSQ header made of 6 bytes:
     * - The uncompressed buffer in bytes
     * - A flag indicating if the file is compressed
     * - The compressed buffer in bytes (should equal the actual file size)
     * - A checksum flag
     * By summing the 6 bytes, the last byte should equal 171
     */
    private func readHSQHeader(_ fileHandle: FileHandle) throws -> ResourceHeader {
        var header = ResourceHeader()
        
        header.uncompressedSize = fileHandle.readUInt16LE()
        header.isCompressed = fileHandle.readByte()
        header.compressedSize = fileHandle.readUInt16LE()

        fileSize = UInt64(header.compressedSize!)

        try fileHandle.seekToEnd()
        let realFileSize = try fileHandle.offset()
        
        if realFileSize != fileSize {
            print("\(fileName): wrong file size (expected=\(realFileSize), actual=\(fileSize)). HSQ file may be corrupted.")
            throw ResourceError.fileSizeMismatch
        }
        
        fileHandle.seek(toFileOffset: 0)
        header.data = try fileHandle.read(upToCount: 6)

        if header.checksumValue != Resource.validChecksum {
            print("\(fileName): invalid checksum. HSQ file may be corrupted.")
            throw ResourceError.checksumMismatch
        }
        
        return header
    }
    

    /**
     * Unpacks HSQ content
     */
    private func unpackHSQ(_ fileHandle: FileHandle) {
        var queue: UInt16 = 0
        
        func readNextBit() -> UInt16 {
            var bit: UInt16 = queue & 1
            queue >>= 1
            
            if (queue == 0) {
                queue = fileHandle.readUInt16LE()
                bit = queue & 1
                queue = 0x8000 | (queue >> 1)
            }

            return bit
        }
        
        // Read the two first bytes of instructions
        var count: UInt16 = 0
        var offset: Int16 = 0
        
        while !fileHandle.isEOF(fileSize) {
            // Series of bits at 1 define the number of bytes to copy
            if readNextBit() == 1 {
                unpackedData.append(fileHandle.readByte())
            } else {
                if readNextBit() == 1 {
                    let b0 = UInt16(fileHandle.readByte())
                    let b1 = UInt16(fileHandle.readByte())
                    
                    count = b0 & 0x7
                    offset = Int16((b0 >> 3) | (b1 << 5)) - 0x2000

                    if count == 0 {
                        count = UInt16(fileHandle.readByte())
                    }
                             
                    // finish the unpacking
                    if count == 0 {
                        break
                    }
                } else {
                    count = readNextBit() * 2
                    count += readNextBit()
                    
                    let distance = fileHandle.readByte()
                    offset = Int16(distance) - 256
                }

                count += 2

                let currentOffset = unpackedData.count
                let startCopy = Int(currentOffset) + Int(offset)
                let endCopy = startCopy + Int(count) - 1
                
                for i in startCopy...endCopy {
                    unpackedData.append(unpackedData[i])
                }
            }
        }
    }
}


extension UInt16 {
    func asBinaryString() -> String {
        var s: String = ""
        
        for i: UInt16 in 0...15 {
            let bitValue = (self & (1 << i)) >> i
            s += "\(bitValue) "
        }
        
        return s
    }
    
    func readBit(_ pos: UInt16) -> UInt16 {
        let mask: UInt16 = 1 << pos
        let bitValue = (self & mask) >> pos
        return bitValue
    }
    
    
    static func fromBytes(_ bytes: [UInt8], _ offset: Int) -> UInt16 {
        let b0 = bytes[offset]
        let b1 = bytes[offset + 1]
        
        let uint16Value = UInt16(b0) << 8 | UInt16(b1)
        return uint16Value
    }
}


extension Int16 {
    static func fromBytes(_ bytes: [UInt8], _ offset: Int) -> Int16 {
        let b0 = bytes[offset]
        let b1 = bytes[offset + 1]
        
        let int16Value = Int16(b0) << 8 | Int16(b1)
        return int16Value
    }
}


extension FileHandle {
    func readUInt16LE() -> UInt16 {
        let data = readData(ofLength: MemoryLayout<UInt8>.size * 2)
        
        guard data.count == 2 else {
            print("readUInt16LE(): Unable to read word")
            return 0
        }
        
        let byteArray = [UInt8](data)
        let uint16Value = UInt16(byteArray[1]) << 8 | UInt16(byteArray[0])

        return uint16Value
    }
    
    
    func readByte() -> UInt8 {
        let data = readData(ofLength: MemoryLayout<UInt8>.size)
        
        guard data.count == 1 else {
            print("readByte(): Unable to read byte")
            return 0
        }

        return data.first!
    }
    
    
    func isEOF(_ fileSize: UInt64) -> Bool {
        do {
            let offset = try offset()
            return offset >= fileSize
        } catch {
            return true
        }
    }
}

