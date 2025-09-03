//
//  CreativeVoice.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 02/09/2025.
//

import Foundation

enum VOCError: Error {
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

/*
 Creative Voice (VOC) file format
 @see https://wiki.multimedia.cx/index.php/Creative_Voice
 @see https://wiki.multimedia.cx/index.php/Creative_8_bits_ADPCM
 @see https://fabiensanglard.net/reverse_engineering_strike_commander/docs/Creative%20Voice%20(VOC)%20file%20format.txt
 */
public final class CreativeVoice {
  private let engine = DuneEngine.shared
  private var resource: Resource
  private var signature: String?
  private var version: UInt16 = 0

  var dataBlocks: [VOCDataBlock] = []
  
  init(_ resource: Resource) {
    self.resource = resource

    parseVOC()
  }
  
  /**
   Saves decompressed HSQ as a VOC file
   */
  func saveAsVOC() {
    let fileName = resource.fileName.replacingOccurrences(of: ".HSQ", with: ".VOC")
    let data = Data(resource.stream!.data)
    
    let downloadsDirectory = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
    let fileURL = downloadsDirectory.appendingPathComponent(fileName)
    
    do {
      try data.write(to: fileURL)
      engine.logger.log(.info, "Array saved to file: \(fileURL.absoluteString)")
    } catch {
      engine.logger.log(.error, "Error saving \(fileName): \(error)")
    }
  }
  
  
  private func parseVOC() {
    resource.stream!.seek(0)
    
    let signatureBytes = resource.stream!.readBytes(19)
    signature = String(bytes: signatureBytes, encoding: .ascii)!
    
    let eofByte = resource.stream!.readByte()
    
    if signature != "Creative Voice File" || eofByte != 0x1A {
      engine.logger.log(.error, "parseVOC(): Invalid signature")
      return
    }
    
    // Header size
    let headerSize = resource.stream!.readUInt16LE()
    
    if headerSize != 26 {
      engine.logger.log(.error, "parseVOC(): Wrong header size")
    }
    
    version = resource.stream!.readUInt16LE()
    
    if version != 0x10A && version != 0x114 {
      engine.logger.log(.error, "parseVOC(): Unknown VOC version: \(String.fromWord(version))")
    }
    
    
    let checksum = resource.stream!.readUInt16LE()
    let computedChecksum = (UInt(~version) + 0x1234) & 0x0000FFFF
    
    if checksum != computedChecksum {
      engine.logger.log(.error, "parseVOC(): Invalid checksum: \(checksum)")
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
          let samplingRate = UInt32(1000000.0 / (256.0 - Float(frequencyDivisor)))
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
          dataBlocks.append(.endRepetition)
          break
        default:
          print("Unsupported block: \(String(format: "%02X", dataTypeCode))")
          break
      }
    }
  }
  
  func dumpInfo() {
    engine.logger.log(.debug, "File: \(resource.fileName)")
    engine.logger.log(.debug, "Signature: \(signature!)")
    engine.logger.log(.debug, "Version: \(version >> 8).\(version & 0xFF)")
    engine.logger.log(.debug, "Blocks:")
    
    for i in 0..<dataBlocks.count {
      switch dataBlocks[i] {
        case .terminate:
          engine.logger.log(.debug, "- Terminate")
        case .soundData(let codec, let samplingRate, let bytes):
          engine.logger.log(.debug, "- Sound data: codec=\(codec), samplingRate=\(samplingRate), bytes=\(bytes.count)")
        case .repetition(let count):
          engine.logger.log(.debug, "- Repeat block start: count=\(count)")
        case .marker(let bytes):
          engine.logger.log(.debug, "- Marker: \(String.fromByte(bytes[0])) - \(String.fromByte(bytes[1]))")
        case .endRepetition:
          engine.logger.log(.debug, "- Repeat block end")
        case .silence(let codec, let length, let samplingRate):
          engine.logger.log(.debug, "- Silence: codec=\(codec), length=\(length), samplingRate=\(samplingRate)")
        case .string(let s):
          engine.logger.log(.debug, "- String: \(s)")
      }
    }
    
    print("")
  }
}
