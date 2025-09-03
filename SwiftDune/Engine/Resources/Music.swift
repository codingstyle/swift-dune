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

import AVFoundation

public final class Music: AudioPlayerItem {
  var type: AudioPlayerItemType {
    return .music
  }
  
  private let engine = DuneEngine.shared
  private var herad: HERAD
  private var resource: Resource
  private var player: AudioPlayer
  
  private var timer: Timer?
  private var currentTicks: Int = 0
  
  init(_ fileName: String, player: AudioPlayer) {
    self.player = player
    self.resource = Resource(fileName)
    self.herad = HERAD(resource)
  }
  
  
  func play() {
    // TODO: Initialize OPL3 with music data for tick-based generation
    
    // Calculate frame count for one tick
    let tickDuration = 1.0 / herad.ticksPerSecond
    
    // Create timer for tick-based audio generation
    self.timer = Timer.scheduledTimer(withTimeInterval: tickDuration, repeats: true, block: { [weak self] _ in
      guard let self = self else { return }
      
      self.currentTicks += 1
      
      guard self.currentTicks <= herad.maxTicks else {
        self.stop()
        return
      }
    })
  }
  
  
  func stop() {
    self.currentTicks = 0
    
    if self.timer != nil {
      self.timer!.invalidate()
      self.timer = nil
    }
    
    // Stop OPL node
    let oplNode = player.node(for: .music)
    oplNode.stop()
  }
  
  
  func dumpInfo() {
    /*engine.logger.log(.debug, "Music file: \(resource.fileName)")
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
    }*/
  }
}


extension AVAudioUnitSampler {
  func playHeradEvent(_ event: HeradEvent) {
    switch event.type {
      case .noteOn(let note, let velocity, let channel):
        self.startNote(note, withVelocity: velocity, onChannel: channel)
      case .noteOff(let note, let channel):
        self.stopNote(note, onChannel: channel)
      case .programChange(let program, let channel):
        self.sendProgramChange(program, onChannel: channel)
      case .pitchBend(let pitchBend, let channel):
        self.sendPitchBend(UInt16(pitchBend), onChannel: channel)
      case .channelPressure(let pressure, let channel):
        self.sendPressure(pressure, onChannel: channel)
      case .controlChange(let controlNumber, let value, let channel):
        self.sendController(UInt8(controlNumber), withValue: UInt8(value), onChannel: channel)
        break
      case .aftertouch(let note, let value, let channel):
        break
      default:
        break
    }
  }
}
