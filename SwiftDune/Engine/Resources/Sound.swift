//
//  Sound.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 28/08/2023.
//

import Foundation

// Sound effect.
// Unpacked HSQ resource is a Creative Voice (VOC) file format
// SD5.HSQ seems uncompressed ??

// @see https://en.wikipedia.org/wiki/Creative_Voice_file
// @see https://wiki.multimedia.cx/index.php/Creative_Voice
// @see https://code.videolan.org/videolan/vlc/-/blob/master/modules/demux/voc.c

// @see https://fr.wikipedia.org/wiki/Waveform_Audio_File_Format

// Convert PCM8 to float : https://github.com/OpenRakis/Spice86/blob/master/src/Spice86.Core/Backend/Audio/SampleConverter.cs

enum SoundError: Error {
    case invalidSignature
    case invalidChecksum
    case wrongHeaderSize
    case unknownVersion
}

enum VOCAudioCodec: UInt8 {
    case unsigned8bitPCM    = 0x00 // 8 bits unsigned PCM
    case creative4bitADPCM  = 0x01 // 4 bits to 8 bits Creative ADPCM
    case creative3bitADCPM  = 0x02 // 3 bits to 8 bits Creative ADPCM (AKA 2.6 bits)
    case creative2bitADPCM  = 0x03 // 2 bits to 8 bits Creative ADPCM
    case signed16bitPCM     = 0x04 // 16 bits signed PCM
    case alaw               = 0x06 // alaw
    case mulaw              = 0x07 // µ-law
    
    var bytesPerFrame: UInt32 {
        switch self {
        case .unsigned8bitPCM, .creative4bitADPCM, .creative2bitADPCM, .alaw, .mulaw:
            return 1
        case .creative3bitADCPM:
            return 3
        case .signed16bitPCM:
            return 2
        }
    }
    
    var bitsPerSample: UInt32 {
        switch self {
        case .unsigned8bitPCM, .alaw, .mulaw:
            return 8
        case .creative4bitADPCM:
            return 4
        case .creative3bitADCPM:
            return 3
        case .creative2bitADPCM:
            return 2
        case .signed16bitPCM:
            return 16
        }
    }
}

enum VOCDataBlock {
    case terminate
    case soundData(codec: VOCAudioCodec, samplingRate: UInt16, bytes: [UInt8])
    case silence(codec: VOCAudioCodec, samplingRate: UInt16, length: UInt16)
    case marker(bytes: [UInt8])
    case string(s: String)
    case repetition(count: UInt16)
    case endRepetition
}


final class Sound {
    private var engine: DuneEngine
    var resource: Resource
    var dataBlocks: [VOCDataBlock] = []
    
    private var signature: String?
    private var version: UInt16 = 0
    
    init(_ fileName: String, engine: DuneEngine) {
        self.resource = Resource(fileName, uncompressed: fileName == "SD5.HSQ")
        self.engine = engine
    }
    
    func play() {
        
    }
    
    
    func saveAsVOC() {
        let fileName = resource.fileName.replacingOccurrences(of: ".HSQ", with: ".VOC")
        let data = Data(resource.stream!.data)
        let filePath = "/Users/christophebuguet/Downloads/\(fileName)"
        
        do {
            try data.write(to: URL(fileURLWithPath: filePath))
            print("Array saved to file: \(filePath)")
        } catch {
            print("Error saving \(fileName): \(error)")
        }
    }
    
    
    func load() throws {
        resource.stream!.seek(0)

        let signatureBytes = resource.stream!.readBytes(20)
        signature = String(bytes: signatureBytes, encoding: .ascii)!

        if signature != "Creative Voice File\u{1a}" {
            throw SoundError.invalidSignature
        }

        // Header size
        let headerSize = resource.stream!.readUInt16LE()
        
        if headerSize != 26 {
            throw SoundError.wrongHeaderSize
        }
        
        version = resource.stream!.readUInt16LE()

        if version != 0x10A && version != 0x114 {
            throw SoundError.unknownVersion
        }

        
        let checksum = resource.stream!.readUInt16LE()
        let computedChecksum = (UInt(~version) + 0x1234) & 0x0000FFFF

        if checksum != computedChecksum {
            throw SoundError.invalidChecksum
        }
         
        // Read data blocks
        var dataTypeCode: UInt8 = 0x01

        while dataTypeCode != 0x00 {
            dataTypeCode = resource.stream!.readByte()

            if dataTypeCode == 0x00 {
                dataBlocks.append(.terminate)
                break
            }
            
            let dataSizeBytes = resource.stream!.readBytes(3)
            let dataSize = UInt32(dataSizeBytes[2]) << 16 | UInt32(dataSizeBytes[1]) << 8 | UInt32(dataSizeBytes[0])

            //print("Data block header: \(String(format: "%02X", dataTypeCode)) | Size: \(dataSize) | Offset: \(resource.stream!.offset)")

            switch dataTypeCode {
            case 0x01, 0x02:
                let frequencyDivisor = resource.stream!.readByte()
                let samplingRate = 1000000 / (256 - UInt32(frequencyDivisor))
                let codec = resource.stream!.readByte()
                
                let audioBytes = resource.stream!.readBytes(dataSize - 2)
                dataBlocks.append(.soundData(codec: VOCAudioCodec(rawValue: codec)!, samplingRate: UInt16(samplingRate), bytes: audioBytes))
            case 0x03:
                let silenceLength = resource.stream!.readUInt16()
                let frequencyDivisor = resource.stream!.readByte()
                let samplingRate = 1000000 / (256 - UInt32(frequencyDivisor))

                dataBlocks.append(.silence(codec: .unsigned8bitPCM, samplingRate: UInt16(samplingRate), length: silenceLength))
            case 0x04:
                let markerBytes = resource.stream!.readBytes(2)
                
                dataBlocks.append(.marker(bytes: markerBytes))
            case 0x05:
                let bytes = resource.stream!.readBytes(dataSize)
                resource.stream!.skip(1)

                dataBlocks.append(.string(s: String(bytes: bytes, encoding: .ascii)!))
            case 0x06:
                let repetitionCount = resource.stream!.readUInt16()
                
                dataBlocks.append(.repetition(count: repetitionCount))
            case 0x07:
                break
            default:
                break //print("Unsupported block: \(String(format: "%02X", dataTypeCode))")
            }
        }
    }
    
    func dumpInfo() {
        print("")
        print("File: \(resource.fileName)")
        print("Signature: \(signature!)")
        print("Version: \(version >> 8).\(version & 0xFF)")
        print("Blocks:")
        
        for i in 0..<dataBlocks.count {
            switch dataBlocks[i] {
            case .terminate:
                print("- Terminate")
            case .soundData(let codec, let samplingRate, let bytes):
                print("- Sound data: codec=\(codec), samplingRate=\(samplingRate), bytes=\(bytes.count)")
            case .repetition(let count):
                print("- Repeat block start: count=\(count)")
            case .endRepetition:
                print("- Repeat block end")
            case .silence(let codec, let length, let samplingRate):
                print("- Silence: codec=\(codec), length=\(length), samplingRate=\(samplingRate)")
            case .string(let s):
                print("- String: \(s)")
            case .marker(let bytes):
                print("- Marker: bytes=\(bytes.count)")
            }
        }

        print("")
    }
}
