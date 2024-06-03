//
//  Sound.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 28/08/2023.
//

import Foundation
import AVFoundation

// Sound effect.
// Unpacked HSQ resource is a Creative Voice (VOC) file format

// @see https://wiki.multimedia.cx/index.php/Creative_Voice
// @see https://wiki.multimedia.cx/index.php/Creative_8_bits_ADPCM

let adpcmStepTable: [Int] = [
    7, 8, 9, 10, 11, 12, 13, 14, 16, 17, 19, 21, 23, 25, 28, 31,
    34, 37, 41, 45, 50, 55, 60, 66, 73, 80, 88, 97, 107, 118, 130, 143,
    157, 173, 190, 209, 230, 253, 279, 307, 337, 371, 408, 449, 494, 544, 598, 658,
    724, 796, 876, 963, 1060, 1166, 1282, 1411, 1552, 1707, 1878, 2066, 2272, 2499, 2749, 3024,
    3327, 3660, 4026, 4428, 4871, 5358, 5894, 6484, 7132, 7845, 8630, 9493, 10442, 11487, 12635, 13899,
    15289, 16818, 18500, 20350, 22385, 24623, 27086, 29794, 32767
]

let adpcmIndexTable: [Int] = [
    -1, -1, -1, -1, 2, 4, 6, 8,
    -1, -1, -1, -1, 2, 4, 6, 8
]

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
    
    var asPCMBuffer: AVAudioPCMBuffer? {
        var bytes: [UInt8] = []
        var codec: VOCAudioCodec
        var samplingRate: CGFloat = 0.0
        var sample: [Float32] = []
        
        switch self {
        case .soundData(let sCodec, let sSamplingRate, let sBytes):
            codec = sCodec
            samplingRate = CGFloat(sSamplingRate)
            bytes = sBytes
            break
        case .silence(let sCodec, let sSamplingRate, let sLength):
            codec = sCodec
            samplingRate = CGFloat(sSamplingRate)
            bytes = [UInt8](repeating: 0, count: Int(sLength))
            break
        default:
            return nil
        }
        
        switch codec {
        case .creative4bitADPCM:
            sample = convertCreative4bitADPCMToFloat32PCM(bytes)
        case .unsigned8bitPCM:
            sample = convertUnsigned8bitPCMToFloat32PCM(bytes)
        default:
            print("Unsupported codec: \(codec)")
        }

        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: samplingRate, channels: 1, interleaved: false)!
        
        let frameCapacity = AVAudioFrameCount(UInt32(sample.count))
        guard let audioBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCapacity) else { return nil }
        
        memcpy(audioBuffer.mutableAudioBufferList.pointee.mBuffers.mData, sample, sample.count * MemoryLayout<Float32>.size)
        audioBuffer.frameLength = frameCapacity
        
        return audioBuffer
    }
    
    
    /**
     Converts samples from unsigned 8-bit PCM to Float32 PCM
     */
    private func convertUnsigned8bitPCMToFloat32PCM(_ eightBitData: [UInt8]) -> [Float32] {
        var floatData = [Float32]()
        var i = 0
        
        // Convert sample from unsigned 8-bit to Float32
        while i < eightBitData.count {
            let tempData = Int16(eightBitData[i]) - 0x80
            let floatSample = Float32(tempData << 8) / 256.0
            floatData.append(floatSample)
            i += 1
        }
        
        return floatData
    }
    
    
    /**
     Decodes and converts samples from Sound Blaster 4-bit ADPCM to Float32 PCM
     */
    private func convertCreative4bitADPCMToFloat32PCM(_ eightBitData: [UInt8]) -> [Float32] {
        var floatData = [Float32]()
        
        var step: Int = 0
        let shift = 0
        let limit = 5
        var prediction = Int16(bitPattern: UInt16(eightBitData[0]))
        var i = 1

        while i < eightBitData.count {
            let value = eightBitData[i] & 0x7F
            let sign: Int16 = (eightBitData[i] & 0x80) > 0 ? 1 : -1
            let sample = Math.clamp(prediction + sign * Int16(value << (step + shift)), 0, 255)

            prediction = sample

            if value >= limit {
                step += 1
            } else if value == 0 {
                step -= 1
            }
            
            step = Math.clamp(step, 0, 3)
            
            let tempData = Int16(sample) - 0x80
            
            let floatSample = Float32(tempData) / 128.0
            floatData.append(floatSample)
            i += 1
        }
        
        return floatData
    }
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
        
        let downloadsDirectory = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        let fileURL = downloadsDirectory.appendingPathComponent(fileName)
        
        do {
            try data.write(to: fileURL)
            print("Array saved to file: \(fileURL.absoluteString)")
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
                let repetitionCount = resource.stream!.readUInt16LE()
                
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
