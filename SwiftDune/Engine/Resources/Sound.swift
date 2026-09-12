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
// @see https://fabiensanglard.net/reverse_engineering_strike_commander/docs/Creative%20Voice%20(VOC)%20file%20format.txt

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

enum VOCDataBlock {
    case terminate
    case soundData(codec: VOCAudioCodec, samplingRate: UInt16, bytes: [UInt8])
    case silence(codec: VOCAudioCodec, samplingRate: UInt16, length: UInt16)
    case marker(bytes: [UInt8])
    case string(s: String)
    case repetition(count: UInt16)
    case endRepetition
}


final class Sound: AudioPlayerItem {
  var type: AudioPlayerItemType {
    return .sound
  }
  
  var fileName: String {
    return resource.fileName
  }
  
  private let engine = DuneEngine.shared
  private var creativeVoice: CreativeVoice
  private var resource: Resource
  private var player: AudioPlayer

  var skipRepeat = false
  var isPlaying = false
  
  init(_ fileName: String, player: AudioPlayer) {
    self.player = player
    self.resource = Resource(fileName, uncompressed: fileName == "SD5.HSQ")
    self.creativeVoice = CreativeVoice(resource)
  }
  
  
  func play() {
    let node = player.node(for: .sound)
    
    if node.isPlaying {
      node.stop()
    }

    print("Playing sound: \(resource.fileName)")
    
    var i = 0
    
    var pendingBuffers: [AVAudioPCMBuffer] = []
    var isRepeating = false
    var repeatCount = 1
    
    while i < creativeVoice.dataBlocks.count {
      let dataBlock = creativeVoice.dataBlocks[i]
      
      switch dataBlock {
        case .endRepetition:
          isRepeating = false
          break
        case .terminate:
          isRepeating = false
          break
        case .soundData(_, _, _):
          let buffer = makePCMBuffer(from: dataBlock)!
          let resampledBuffer = player.resampledBuffer(buffer)
          pendingBuffers.append(resampledBuffer!)
          isRepeating = false
          break
        case .repetition(let count):
          isRepeating = true
          repeatCount = Int(count)
          break
        default:
          break
      }
      
      if isRepeating && !skipRepeat {
        i += 1
        continue
      }
      
      node.scheduleBuffersLoop(pendingBuffers, numberOfLoops: repeatCount)
      node.play()
      
      i += 1
      
      repeatCount = 1
      pendingBuffers = []
    }
    
    // print("[AudioPlayer] Audio graph = \(audioEngine.debugDescription)")
    isPlaying = true
  }
  
  
  func stop() {
    let node = player.node(for: .sound)
    
    if node.isPlaying {
      node.stop()
    }
    
    isPlaying = false
  }
    
  
  /**
   Converts VOC data to an AVAudioPCMBuffer
   */
  private func makePCMBuffer(from dataBlock: VOCDataBlock) -> AVAudioPCMBuffer? {
    var bytes: [UInt8] = []
    var codec: VOCAudioCodec
    var samplingRate: CGFloat = 0.0
    var sample: [Float32] = []
    
    switch dataBlock {
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
        DuneEngine.shared.logger.log(.error, "Unsupported codec: \(codec)")
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
      let floatSample = Float32(tempData) / 128.0
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
  
    
  func dumpInfo() {
    creativeVoice.dumpInfo()
  }
}
