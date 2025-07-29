//
//  Music.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 06/10/2024.
//

// HERAD documentation: https://www.vgmpf.com/Wiki/index.php/HERAD
// DUNE AdLib implementation: https://github.com/synamaxmusic/herad/blob/main/DFADL.ASM

// HERAD implementation on ScummVM: https://github.com/bluegr/scummvm/tree/dune/engines/dune/sound
// HERAD implementation on ADPlug: https://github.com/adplug/adplug/blob/herad-dev/src/herad.cpp

// AVAudioUnitMIDIInstrument root class: https://developer.apple.com/documentation/avfaudio/avaudiounitmidiinstrument

// Apple MIDI impl on VLC: https://github.com/videolan/vlc/blob/master/modules/codec/audiotoolbox_midi.c

struct HeradEvent {
  var ticks: UInt32
  var type: HeradEventType
  
  var asString: String {
    switch self.type {
      case .noteOff(let noteNumber, let channel): return "noteOff: ticks=\(ticks), noteNumber=\(noteNumber), channel=\(channel)"
      case .noteOn(let noteNumber, let velocity, let channel): return "noteOn: ticks=\(ticks), noteNumber=\(noteNumber), velocity=\(velocity), channel=\(channel)"
      case .aftertouch(let noteNumber, let value, let channel): return "aftertouch: ticks=\(ticks), noteNumber=\(noteNumber), value=\(value), channel=\(channel)"
      case .controlChange(let controlNumber, let value, let channel): return "controlChange: ticks=\(ticks), controlNumber=\(controlNumber), value=\(value), channel=\(channel)"
      case .programChange(let programNumber, let channel): return "programChange: ticks=\(ticks), programNumber=\(programNumber), channel=\(channel)"
      case .channelPressure(let pressure, let channel): return "channelPressure: ticks=\(ticks), pressure=\(pressure), channel=\(channel)"
      case .pitchBend(let value, let channel): return "pitchBend: ticks=\(ticks), value=\(value), channel=\(channel)"
      case .endTrack: return "endTrack"
    }
  }
}


enum HeradEventType {
  case noteOff(noteNumber: UInt8, channel: UInt8)
  case noteOn(noteNumber: UInt8, velocity: UInt8, channel: UInt8)
  case aftertouch(noteNumber: UInt8, value: UInt8, channel: UInt8)
  case controlChange(controlNumber: UInt8, value: UInt8, channel: UInt8)
  case programChange(programNumber: UInt8, channel: UInt8)
  case channelPressure(pressure: UInt8, channel: UInt8)
  case pitchBend(value: UInt8, channel: UInt8)
  case endTrack
}


struct HeradHeader {
  var chunkSize: UInt16 = 0
  var offsets: [UInt16] = []
  var loopStart: UInt16 = 0
  var loopEnd: UInt16 = 0
  var loopCount: UInt16 = 0
  var speed: UInt16 = 0
}

struct HeradTrack {
  var offset: UInt16 = 0
  var size: UInt16 = 0
  var data: [UInt8] = []
  var events: [HeradEvent] = []
  var instrument: HeradInstrument?
  
  func event(at ticks: Int) -> HeradEvent? {
    var i = 0
    
    while i < events.count {
      if events[i].ticks > ticks {
        return nil
      }

      if events[i].ticks < ticks {
        i += 1
        continue
      }
      
      return events[i]
    }

    return nil
  }
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

struct HeradChannel {
  var program: HeradInstrument
  var playProgram: HeradInstrument
  var note: UInt8
  var keyOn: Bool
  var bend: UInt8
  var pitchSlideDuration: UInt8
}


final class Music {
  private let engine = DuneEngine.shared
  private var resource: Resource
  
  private let headerSize: UInt32 = 52
  private let instrumentsSize = 40
  private let voicesSize = 9
  private let tracksSize = 21
  
  private let fNum: [UInt16] = [
    343, 364, 385, 408, 433, 459, 486, 515, 546, 579, 614, 650
  ]
  
  private let fineBend: [UInt8] = [
    19, 21, 21, 23, 25, 26, 27, 29, 31, 33, 35, 36, 37
  ]
  
  private let coarseBend: [UInt8] = [
    0, 5, 10, 15, 20,
    0, 6, 12, 18, 24
  ]

  private let refreshRate = 200.299 // Hz (= 500 BPM)
  private let defaultBPM = 500.0
  private let ticksPerBeat = 24.0
  
  var ticksPerSecond: Double {
    let speedRatio = Double(header.speed) / 256.0
    let bpm = defaultBPM / speedRatio
    return (bpm * ticksPerBeat) / 60.0
  }
  
  var maxTicks: UInt32 = 0

  private var header = HeradHeader()
  var instruments: [HeradInstrument] = []
  var tracks: [HeradTrack] = []
  
  
  init(_ fileName: String) {
    resource = Resource(fileName)
    parseMusicFile()
  }
  
  
  private func parseMusicFile() {
    parseHeradHeader()
    parseHeradTracks()
    parseHeradInstruments()
  }
  
  
  private func parseHeradHeader() {
    // Header data
    header.chunkSize = resource.stream!.readUInt16LE()
    
    var i = 0
    
    // Maximum 21 tracks
    while i < tracksSize {
      let offset = resource.stream!.readUInt16LE()
      
      if offset != 0 {
        header.offsets.append(offset)
      }

      i += 1
    }
    
    header.loopStart = resource.stream!.readUInt16LE()
    header.loopEnd = resource.stream!.readUInt16LE()
    header.loopCount = resource.stream!.readUInt16LE()
    header.speed = resource.stream!.readUInt16LE()
  }
  
  
  
  private func parseHeradTracks() {
    let maxOffset = header.chunkSize
    
    self.maxTicks = 0
    
    var i = 0
    
    while i < header.offsets.count {
      let size = (i < header.offsets.count - 1 ? header.offsets[i + 1] : maxOffset - 1) - header.offsets[i]
      
      var track = HeradTrack()
      track.offset = header.offsets[i]
      track.size = UInt16(size)
      track.data = resource.stream!.readBytes(UInt32(size))
      
      // Read track data and interpret the MIDI messages
      var n = 0
      var ticks: UInt32 = 0
      
      while n < size {
        var deltaTicks: UInt32 = 0
        
        repeat {
          deltaTicks = (deltaTicks << 7) | (UInt32(track.data[n]) & 0x7F)

          if (track.data[n] & 0x80) == 0 {
            break
          }

          n += 1
        } while (n < size)
        
        ticks += deltaTicks
        n += 1
        
        if n >= size {
          break
        }
        
        if track.data[n] == 0xFF {
          track.events.append(HeradEvent(
            ticks: ticks,
            type: .endTrack
          ))
          n += 1
          continue
        } else {
          let eventType = track.data[n] & 0xF0
          var trackIndex = UInt8(tracks.count + 1)
          
          switch eventType {
            case 0x80:
              // NOTE: velocity is ignored
              let note = heradNoteToMIDINote(track.data[n + 1], &trackIndex)
              track.events.append(HeradEvent(
                ticks: ticks,
                type: .noteOff(noteNumber: note, channel: trackIndex)
              ))
              n += 3
              break
            case 0x90:
              let note = heradNoteToMIDINote(track.data[n + 1], &trackIndex)
              track.events.append(HeradEvent(
                ticks: ticks,
                type: .noteOn(noteNumber: note, velocity: track.data[n + 2], channel: trackIndex)
              ))
              n += 3
              break
            case 0xA0:
              let note = heradNoteToMIDINote(track.data[n + 1], &trackIndex)
              track.events.append(HeradEvent(
                ticks: ticks,
                type: .aftertouch( noteNumber: note, value: track.data[n + 2], channel: trackIndex)
              ))
              n += 3
              break
            case 0xB0:
              track.events.append(HeradEvent(
                ticks: ticks,
                type: .controlChange(controlNumber: track.data[n + 1], value: track.data[n + 2], channel: trackIndex)
              ))
              n += 3
              break
            case 0xC0:
              track.events.append(HeradEvent(
                ticks: ticks,
                type: .programChange(programNumber: track.data[n + 1], channel: trackIndex)
              ))
              n += 2
              break
            case 0xD0:
              track.events.append(HeradEvent(
                ticks: ticks,
                type: .channelPressure(pressure: track.data[n + 1], channel: trackIndex)
              ))
              n += 2
              break
            case 0xE0:
              track.events.append(HeradEvent(
                ticks: ticks,
                type: .pitchBend(value: track.data[n + 1], channel: trackIndex)
              ))
              n += 2
              break
            default:
              n += 1
              break
          }
        }
      }
      
      self.maxTicks = max(self.maxTicks, ticks)
      
      tracks.append(track)
      i += 1
    }
  }
  
  
  private func parseHeradInstruments() {
    resource.stream!.seek(UInt32(header.chunkSize))

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
  
  
  func heradNoteToMIDINote(_ noteNumber: UInt8, _ channel: inout UInt8) -> UInt8 {
    let note = Int(noteNumber)
    let octave = UInt8(note / fNum.count)
    let key = UInt8(note % fNum.count)
    
    return key + octave * 12
  }
  
  
  func dumpInfo() {
    engine.logger.log(.debug, "Music file: \(resource.fileName)")
    engine.logger.log(.debug, " - Header: chunkSize=\(header.chunkSize), loopStart=\(header.loopStart), loopEnd=\(header.loopEnd), loopCount=\(header.loopCount),speed=\(String.fromWord(header.speed))")
    
    var n = 0
    
    for track in tracks {
      engine.logger.log(.debug, " - Track #\(n): offset=\(track.offset), size=\(track.size)")
      
      for event in track.events {
        engine.logger.log(.debug, "    - \(event.asString)")
      }
      
      n += 1
    }

    n = 0

    for instrument in instruments {
      engine.logger.log(.debug, " - Instrument #\(n): voiceNumber=\(instrument.voiceNumber)")

      n += 1
    }
  }
}

