//
//  Music.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 06/10/2024.
//

// HERAD documentation: https://www.vgmpf.com/Wiki/index.php/HERAD
// AdLib implementation: https://github.com/synamaxmusic/herad/blob/main/DFADL.ASM
// ScummVM implementation: https://github.com/bluegr/scummvm/tree/dune/engines/dune/sound

// https://developer.apple.com/documentation/avfaudio/avaudiounitmidiinstrument

struct HeradHeader {
  var chunkSize: UInt16 = 0
  var offsets: [UInt16] = []
  var loopStart: UInt16 = 0
  var loopEnd: UInt16 = 0
  var loopCount: UInt16 = 0
  var speed: UInt16 = 0
}


struct HeradInstrument {
  var mode: Int8 = 0
  var voiceNumber: UInt8 = 0
  var modKeyScalingLevel: UInt8 = 0
  var modFrequencyMultiplier: UInt8 = 0
  var feedback: UInt8 = 0
  var modAttack: UInt8 = 0
  var modSustain: UInt8 = 0
  var modEnvelopeGain: UInt8 = 0
  var modDecay: UInt8 = 0
  var modRelease: UInt8 = 0
  var modOutputLevel: UInt8 = 0
  var modAmplitudeModulation: UInt8 = 0
  var modFrequencyVibrato: UInt8 = 0
  var modKeyScalingRate: UInt8 = 0
  var connector: UInt8 = 0
  var carrierKeyScalingLevel: UInt8 = 0
  var carrierFrequencyMultiplier: UInt8 = 0
  var panning: UInt8 = 0
  var carrierAttack: UInt8 = 0
  var carrierSustain: UInt8 = 0
  var carrierEnvelopeGain: UInt8 = 0
  var carrierDecay: UInt8 = 0
  var carrierRelease: UInt8 = 0
  var carrierOutputLevel: UInt8 = 0
  var carrierAmplitudeModulation: UInt8 = 0
  var carrierFrequencyVibrato: UInt8 = 0
  var carrierKeyScalingRate: UInt8 = 0
  var feedbackScalingAftertouch: Int8 = 0         // HERAD macro
  var modWaveformSelect: UInt8 = 0
  var carrierWaveformSelect: UInt8 = 0
  var modOutputLevelScaling: Int8 = 0             // HERAD macro
  var carrierOutputLevelScaling: Int8 = 0         // HERAD macro
  var feedbackScalingVelocity: Int8 = 0           // HERAD macro
  var pitchSlideRangeFlag: UInt8 = 0              // HERAD macro
  var rootNodeTranspose: UInt8 = 0                // HERAD macro
  var pitchSlideDuration: UInt8 = 0               // HERAD macro
  var pitchSlideRange: Int8 = 0                   // HERAD macro
  var unused: UInt8 = 0
  var modOutputLevelAftertouchScaling: Int8 = 0   // HERAD macro
  var carrierOutputLevelAftertouchScaling: Int8 = 0  // HERAD macro
}


final class Music {
  private let engine = DuneEngine.shared
  private var resource: Resource
  
  private let headerSize: UInt32 = 52
  private let instrumentsSize = 40
  
  private let speedDivider: [UInt16: Float] = [
    0x0100: 1.0,
    0x03E0: 3.875,
    0x0400: 4.0,
    0x042B: 4.168,
    0x04B8: 4.71875,
    0x0500: 5.0
  ]
  
  private var header: HeradHeader?
  private var instruments: [HeradInstrument] = []
  
  
  init(_ fileName: String) {
    self.resource = Resource(fileName)
    parseMusicFile()
    dumpInfo()
  }
  
  
  private func parseMusicFile() {
    parseHeradHeader()
    
    // MIDI data
    //let midiData = resource.stream!.readBytes(UInt32(chunkSize) - headerSize)

    // Instruments data
    parseHeradInstruments()
  }
  
  
  private func parseHeradHeader() {
    header = HeradHeader()
    
    // Header data
    header!.chunkSize = resource.stream!.readUInt16LE()
    
    var i = 0
    
    while i < 21 {
      header!.offsets.append(resource.stream!.readUInt16LE())
      i += 1
    }
    
    header!.loopStart = resource.stream!.readUInt16LE()
    header!.loopEnd = resource.stream!.readUInt16LE()
    header!.loopCount = resource.stream!.readUInt16LE()
    header!.speed = resource.stream!.readUInt16LE()
  }
  
  
  private func parseHeradInstruments() {
    resource.stream!.seek(UInt32(header!.chunkSize))

    let instrumentsCount = Int(resource.stream!.size - resource.stream!.offset) / instrumentsSize    
    var i = 0
    
    while i < instrumentsCount {
      var instrument = HeradInstrument()
      
      instrument.mode = resource.stream!.readSByte()
      instrument.voiceNumber = resource.stream!.readByte()
      instrument.modKeyScalingLevel = resource.stream!.readByte()
      instrument.modFrequencyMultiplier = resource.stream!.readByte()
      instrument.feedback = resource.stream!.readByte()
      instrument.modAttack = resource.stream!.readByte()
      instrument.modSustain = resource.stream!.readByte()
      instrument.modEnvelopeGain = resource.stream!.readByte()
      instrument.modDecay = resource.stream!.readByte()
      instrument.modRelease = resource.stream!.readByte()
      instrument.modOutputLevel = resource.stream!.readByte()
      instrument.modAmplitudeModulation = resource.stream!.readByte()
      instrument.modFrequencyVibrato = resource.stream!.readByte()
      instrument.modKeyScalingRate = resource.stream!.readByte()
      instrument.connector = resource.stream!.readByte()
      instrument.carrierKeyScalingLevel = resource.stream!.readByte()
      instrument.carrierFrequencyMultiplier = resource.stream!.readByte()
      instrument.panning = resource.stream!.readByte()
      instrument.carrierAttack = resource.stream!.readByte()
      instrument.carrierSustain = resource.stream!.readByte()
      instrument.carrierEnvelopeGain = resource.stream!.readByte()
      instrument.carrierDecay = resource.stream!.readByte()
      instrument.carrierRelease = resource.stream!.readByte()
      instrument.carrierOutputLevel = resource.stream!.readByte()
      instrument.carrierAmplitudeModulation = resource.stream!.readByte()
      instrument.carrierFrequencyVibrato = resource.stream!.readByte()
      instrument.carrierKeyScalingRate = resource.stream!.readByte()
      instrument.feedbackScalingAftertouch = resource.stream!.readSByte()
      instrument.modWaveformSelect = resource.stream!.readByte()
      instrument.carrierWaveformSelect = resource.stream!.readByte()
      instrument.modOutputLevelScaling = resource.stream!.readSByte()
      instrument.carrierOutputLevelScaling = resource.stream!.readSByte()
      instrument.feedbackScalingVelocity = resource.stream!.readSByte()
      instrument.pitchSlideRangeFlag = resource.stream!.readByte()
      instrument.rootNodeTranspose = resource.stream!.readByte()
      instrument.pitchSlideDuration = resource.stream!.readByte()
      instrument.pitchSlideRange = resource.stream!.readSByte()
      instrument.unused = resource.stream!.readByte()
      instrument.modOutputLevelAftertouchScaling = resource.stream!.readSByte()
      instrument.carrierOutputLevelAftertouchScaling = resource.stream!.readSByte()
      
      instruments.append(instrument)
      i += 1
    }
  }
  
  
  private func dumpInfo() {
    engine.logger.log(.debug, "Music file: \(resource.fileName)")
    engine.logger.log(.debug, " - Header: chunkSize=\(header!.chunkSize), loopStart=\(header!.loopStart), loopEnd=\(header!.loopEnd), loopCount=\(header!.loopCount),speed=\(String.fromWord(header!.speed))")
    
    var n = 0
    
    for offset in header!.offsets {
      engine.logger.log(.debug, " - Track #\(n): \(offset)")
      n += 1
    }

    for instrument in instruments {
      engine.logger.log(.debug, " - Instrument: ")
    }
  }
}

