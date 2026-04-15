//
//  Music.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 06/10/2024.
//

import AVFoundation

/*
 @see https://github.com/bluegr/scummvm/blob/dune/engines/dune/sound/midiadlib.cpp
 @see https://github.com/adplug/adplug/blob/herad-dev/src/herad.cpp#L862 (better implementation?)
 */

final class Music: AudioPlayerItem {
  var type: AudioPlayerItemType {
    return .music
  }
  
  private let engine = DuneEngine.shared
  private var herad: HERAD
  private var resource: Resource
  private var player: AudioPlayer
  
  private var currentHeradTicks: Int = 0
  private(set) var isPlaying: Bool = false
  private var trackMuteMask: UInt32 = 0
  
  init(_ fileName: String, player: AudioPlayer) {
    self.player = player
    self.resource = Resource(fileName)
    self.herad = HERAD(resource)
  }
  
  
  func play() {
    // Initialize channels with default program (instrument 0) if available
    // This ensures notes can play even if no program change event is received
    if !herad.instruments.isEmpty {
      let defaultInstrument = herad.instruments[0]
      
      for channelIdx in 0..<herad.channels.count {
        if herad.channels[channelIdx].playProgram == nil {
          herad.channels[channelIdx].playProgram = defaultInstrument
          herad.channels[channelIdx].program = defaultInstrument
          // Also configure OPL3 for this channel with the default instrument
          programChange(0, UInt8(channelIdx))
        }
      }
    }
    
    self.isPlaying = true
    self.currentHeradTicks = 0

    // Reset track cursors for sequential event processing
    var trackIdx = 0
    
    while trackIdx < herad.tracks.count {
      herad.tracks[trackIdx].eventCursor = 0
      trackIdx += 1
    }
    
    // Configure AudioPlayer with tick rate for synchronized event processing
    player.oplSamplesPerTick = AudioPlayer.oplSampleRate / herad.ticksPerSecond
    
    // Set up the tick callback - invoked once per HERAD tick at the correct sample boundary
    player.oplTickCallback = { [weak self] in
      guard let self = self, self.isPlaying else { return false }
      
      // Check if music has ended
      guard self.currentHeradTicks <= self.herad.maxTicks else {
        self.isPlaying = false
        
        DispatchQueue.main.async {
          self.stop()
          self.engine.logger.log(.debug, "Music is finished: \(self.resource.fileName)")
        }
        
        return false
      }
      
      // Process events for the current tick, then advance
      self.processEvents()
      self.currentHeradTicks += 1
      return true
    }
    
    // Start OPL3 audio generation (this will call the tick callback at each tick boundary)
    player.startOPL3()
  }
  
  
  func stop() {
    self.isPlaying = false

    // Stop OPL3 audio generation and silence all channels
    player.stopOPL3()
    
    self.currentHeradTicks = 0

    // Reset OPL3
    oplWriteRegister(0x08, 64)   // Enable Note-Sel
    oplWriteRegister(0x23, 238)  // Tremolo/Vibrato/etc
    oplWriteRegister(0xBD, 0)    // Disable Percussion Mode
  }
  
  
  // MARK: - Track info
  
  var currentTick: Int {
    return currentHeradTicks
  }

  var trackCount: Int {
    return herad.tracks.count
  }
  
  var totalTicks: UInt32 {
    return herad.maxTicks
  }
  
  func trackEvents(at index: Int) -> [HeradEvent] {
    return herad.tracks[index].events
  }

  /// Returns the instrument associated with a track by looking at its first programChange event.
  /// Falls back to instrument at track index if no programChange is found.
  func trackInstrument(at index: Int) -> (programNumber: Int, instrument: HeradInstrument)? {
    let events = herad.tracks[index].events

    // Look for the first programChange event in this track
    var eventIdx = 0
    while eventIdx < events.count {
      if case .programChange(let programNumber, _) = events[eventIdx].type {
        let progIdx = Int(programNumber)
        if progIdx < herad.instruments.count {
          return (progIdx, herad.instruments[progIdx])
        }
      }
      eventIdx += 1
    }

    // Fall back to instrument at track index if available
    if index < herad.instruments.count {
      return (index, herad.instruments[index])
    }

    return nil
  }
  
  func isTrackMuted(_ index: Int) -> Bool {
    return (trackMuteMask & (UInt32(1) << index)) != 0
  }
  
  func setTrackMuted(_ index: Int, _ muted: Bool) {
    if muted {
      trackMuteMask |= (UInt32(1) << index)
    } else {
      trackMuteMask &= ~(UInt32(1) << index)
    }
  }
  
  
  private func processEvents() {
    let tick = self.currentHeradTicks

    // Process pitch slides every tick for all active channels (adplug: macroSlide)
    var chIdx = 0
    while chIdx < herad.channels.count {
      if herad.channels[chIdx].pitchSlideDuration > 0 && herad.channels[chIdx].keyOn {
        macroSlide(UInt8(chIdx))
      }
      chIdx += 1
    }

    var trackIdx = 0

    while trackIdx < herad.tracks.count {
      // Skip muted tracks but advance cursor to stay in sync
      if (trackMuteMask & (UInt32(1) << trackIdx)) != 0 {
        while herad.tracks[trackIdx].eventCursor < herad.tracks[trackIdx].events.count {
          let event = herad.tracks[trackIdx].events[herad.tracks[trackIdx].eventCursor]
          if event.ticks > tick { break }
          herad.tracks[trackIdx].eventCursor += 1
        }
        trackIdx += 1
        continue
      }

      // Use cursor to avoid re-scanning from the start every tick
      while herad.tracks[trackIdx].eventCursor < herad.tracks[trackIdx].events.count {
        let event = herad.tracks[trackIdx].events[herad.tracks[trackIdx].eventCursor]

        // Events are sorted by tick: skip past events (advance cursor)
        if event.ticks < tick {
          herad.tracks[trackIdx].eventCursor += 1
          continue
        }

        // Future event: stop processing this track
        if event.ticks > tick {
          break
        }

        // event.ticks == tick: process this event and advance cursor
        herad.tracks[trackIdx].eventCursor += 1

        switch event.type {
          case .noteOn(let note, let velocity, let channel):
            eventNoteOn(channel, note, Int8(bitPattern: velocity))
          case .noteOff(let note, let channel):
            eventNoteOff(channel, note)
          case .pitchBend(let value, let channel):
            eventPitchBend(channel, value)
          case .programChange(let programNumber, let channel):
            eventProgramChange(channel, programNumber)
          case .aftertouch(_, let value, let channel):
            eventAftertouch(channel, value)
          case .channelPressure(let pressure, let channel):
            eventAftertouch(channel, pressure)
          case .controlChange:
            break
          default:
            break
        }
      }

      trackIdx += 1
    }
  }
  
  
  private func oplWriteRegister(_ register: UInt16, _ value: UInt8) {
    // Lock-free direct writes since events are processed synchronously
    // on the same serial queue as audio generation
    player.opl3fm.writeRegisterDirect(register, value)
  }
  
  
  private func eventNoteOn(_ channelIndex: UInt8, _ note: UInt8, _ velocity: Int8) {
    let idx = Int(channelIndex)

    // Check if channel has a program assigned
    if herad.channels[idx].playProgram == nil {
      engine.logger.log(.error, "eventNoteOn: channel \(channelIndex) has no program assigned. Note will be skipped.")
      return
    }

    // Turn off last note on (must mutate array directly - HeradChannel is a struct!)
    if herad.channels[idx].keyOn {
      herad.channels[idx].keyOn = false
      playNote(channelIndex, herad.channels[idx].note, .noteOff)
    }

    herad.channels[idx].note = note
    herad.channels[idx].keyOn = true
    herad.channels[idx].bend = herad.bendCenter
    playNote(channelIndex, note, .noteOn)

    guard let instrument = herad.channels[idx].playProgram else {
      engine.logger.log(.error, "eventNoteOn(): Invalid instrument/playProgram for channel \(channelIndex)")
      return
    }

    if instrument.modOutputLevelScaling != 0 {
      macroModOutput(channelIndex, instrument, instrument.modOutputLevelScaling, velocity)
    }

    if instrument.carrierOutputLevelScaling != 0 {
      macroCarrierOutput(channelIndex, instrument, instrument.carrierOutputLevelScaling, velocity)
    }

    if instrument.feedbackScalingVelocity != 0 {
      macroFeedback(channelIndex, instrument, instrument.feedbackScalingVelocity, velocity)
    }
  }
    

  private func eventNoteOff(_ channelIndex: UInt8, _ note: UInt8) {
    let idx = Int(channelIndex)

    if herad.channels[idx].note != note || !herad.channels[idx].keyOn {
      return
    }

    herad.channels[idx].keyOn = false
    playNote(channelIndex, herad.channels[idx].note, .noteOff)
  }
  
  
  private func eventProgramChange(_ channelIndex: UInt8, _ programNumber: UInt8) {
    // engine.logger.log(.debug, "eventProgramChange: channel=\(channelIndex), program=\(programNumber), instruments.count=\(herad.instruments.count)")
    
    if programNumber >= herad.instruments.count {
      engine.logger.log(.error, "eventProgramChange: programNumber \(programNumber) >= instruments.count \(herad.instruments.count)")
      return
    }
    
    let program = herad.instruments[Int(programNumber)]
    
    herad.channels[Int(channelIndex)].program = program
    herad.channels[Int(channelIndex)].playProgram = program
    
    programChange(programNumber, channelIndex)
  }
  

  private func eventAftertouch(_ channel: UInt8, _ velocity: UInt8) {
    guard let instrument = herad.channels[Int(channel)].playProgram else {
      engine.logger.log(.error, "eventAftertouch(): Invalid instrument/playProgram for channel \(channel)")
      return
    }
    
    if instrument.modOutputLevelAftertouchScaling != 0 {
      macroModOutput(channel, instrument, instrument.modOutputLevelAftertouchScaling, Int8(velocity))
    }
    
    if instrument.carrierOutputLevelAftertouchScaling != 0 {
      macroCarrierOutput(channel, instrument, instrument.carrierOutputLevelAftertouchScaling, Int8(velocity))
    }
    
    if instrument.feedbackScalingAftertouch != 0 {
      macroFeedback(channel, instrument, instrument.feedbackScalingAftertouch, Int8(velocity))
    }
  }
  
  
  private func eventPitchBend(_ channelIndex: UInt8, _ bend: UInt8) {
    let idx = Int(channelIndex)

    herad.channels[idx].bend = bend

    if herad.channels[idx].keyOn {
      playNote(channelIndex, herad.channels[idx].note, .noteUpdate)
    }
  }
  
  
  private func playNote(_ channelIndex: UInt8, _ note: UInt8, _ state: HeradNote) {
    let idx = Int(channelIndex)
    var note = note

    guard let instrument = herad.channels[idx].playProgram else {
      engine.logger.log(.error, "playNote(): Invalid instrument/playProgram for channel \(channelIndex)")
      return
    }

    if instrument.rootNodeTranspose != 0 {
      macroTranspose(&note, instrument)
    }

    note = note &- 24  // Wrapping subtraction to handle underflow

    // Clip notes too low/too high (adplug: note >= 0x60, not >)
    if state != .noteUpdate && note >= 0x60 {
      note = 0
    }

    // Compute octave/key on Int to avoid Int8 overflow when note > 127
    // (reachable during .noteUpdate for low notes after wrapping subtraction)
    let noteInt = Int(note)
    var octave = Int8(noteInt / herad.notesSize)
    var key = Int8(noteInt % herad.notesSize)

    // Mutate pitchSlideDuration directly on the array (HeradChannel is a struct)
    if state != .noteUpdate && instrument.pitchSlideDuration != 0 {
      herad.channels[idx].pitchSlideDuration = (state == .noteOn ? instrument.pitchSlideDuration : 0)
    }

    let bend = Int16(herad.channels[idx].bend)
    var amount: Int16 = 0
    var detune: Int16 = 0
    var amountLow: UInt8 = 0
    var amountHigh: UInt8 = 0

    let signedBendCenter = Int16(herad.bendCenter)

    // pitchSlideRangeFlag bit 0 selects fine vs coarse tuning (adplug: mc_slide_coarse)
    // When bit 0 is CLEAR → fine tune; when bit 0 is SET → coarse tune
    if (instrument.pitchSlideRangeFlag & 1) == 0 {
      // Fine tune
      if bend - signedBendCenter < 0 {
        // Slide down
        amount = signedBendCenter - bend
        amountLow = UInt8(amount >> 5)
        amountHigh = UInt8((amount << 3) & 0xFF)
        key -= Int8(amountLow)

        if key < 0 {
          key += Int8(herad.notesSize)
          octave -= 1
        }

        if octave < 0 {
          key = 0
          octave = 0
        }

        // adplug: fine_bend[key] (not key+1 for slide down)
        // IMPORTANT: parentheses required! Swift >> has HIGHER precedence than *
        // (opposite of C). Without parens, a * b >> 8 = a * (b >> 8) = a * 0 = 0
        detune = -1 * ((Int16(herad.fineBend[Int(key)]) * Int16(amountHigh)) >> 8)
      } else {
        // Slide up
        amount = bend - signedBendCenter
        amountLow = UInt8(amount >> 5)
        amountHigh = UInt8((amount << 3) & 0xFF)
        key += Int8(amountLow)

        if key >= Int8(herad.notesSize) {
          key -= Int8(herad.notesSize)
          octave += 1
        }

        // adplug: fine_bend[key + 1] for slide up
        // Parentheses required: Swift >> has higher precedence than *
        detune = (Int16(herad.fineBend[Int(key) + 1]) * Int16(amountHigh)) >> 8
      }
    } else {
      // Coarse tune
      var offset: UInt8 = 0

      if bend - signedBendCenter < 0 {
        // Slide down
        amount = signedBendCenter - bend
        key -= Int8(amount / 5)

        if key < 0 {
          key += Int8(herad.notesSize)
          octave -= 1
        }

        if octave < 0 {
          key = 0
          octave = 0
        }

        offset = UInt8((amount % 5) + (key >= 6 ? 5 : 0))
        // adplug: detune = -1 * coarse_bend[offset] (negative for slide down)
        detune = -1 * Int16(herad.coarseBend[Int(offset)])
      } else {
        // Slide up (was missing entirely)
        amount = bend - signedBendCenter
        key += Int8(amount / 5)

        if key >= Int8(herad.notesSize) {
          key -= Int8(herad.notesSize)
          octave += 1
        }

        offset = UInt8((amount % 5) + (key >= 6 ? 5 : 0))
        detune = Int16(herad.coarseBend[Int(offset)])
      }
    }

    // Use wrapping addition since detune can be negative (reinterpreted as large UInt16)
    setFrequency(channelIndex, UInt8(octave), herad.fNum[Int(key)] &+ UInt16(bitPattern: detune), state != .noteOff)
  }
  
  
  ///
  /// Program change
  ///
  private func programChange(_ program: UInt8, _ channel: UInt8) {
    let instrument = herad.instruments[Int(program)]
    // Use channel (not program) to determine which OPL3 slots to configure
    let slotOffset = UInt16(herad.slotOffset[Int(channel) % herad.voicesSize])

    var reg: UInt16 = 0
    var val: UInt8 = 0
    
    // Amp Mod / Vibrato / EG type / Key Scaling / Multiple
    reg = 0x20 + slotOffset
    val = (instrument.modFrequencyMultiplier & 15) |
      ((instrument.modKeyScalingRate & 1) << 4) |
      ((instrument.modEnvelopeGain > 0 ? 1 : 0) << 5) |
      ((instrument.modFrequencyVibrato & 1) << 6) |
      ((instrument.modAmplitudeModulation & 1) << 7)
    oplWriteRegister(reg, val)
    
    reg += 3
    val = (instrument.carrierFrequencyMultiplier & 15) |
      ((instrument.carrierKeyScalingRate & 1) << 4) |
      ((instrument.carrierEnvelopeGain > 0 ? 1 : 0) << 5) |
      ((instrument.carrierFrequencyVibrato & 1) << 6) |
      ((instrument.carrierAmplitudeModulation & 1) << 7)
    oplWriteRegister(reg, val)
    
    // Key scaling level / Output level
    reg = 0x40 + slotOffset
    val = (instrument.modOutputLevel & 63) |
      ((instrument.modKeyScalingLevel & 3) << 6)
    oplWriteRegister(reg, val)
    
    reg += 3
    val = (instrument.carrierOutputLevel & 63) |
      ((instrument.carrierKeyScalingLevel & 3) << 6)
    oplWriteRegister(reg, val)
    
    // Attack Rate / Decay Rate
    reg = 0x60 + UInt16(slotOffset)
    val = (instrument.modDecay & 15) |
      ((instrument.modAttack & 15) << 4)
    oplWriteRegister(reg, val)
    
    reg += 3;
    val = (instrument.carrierDecay & 15) |
      ((instrument.carrierAttack & 15) << 4)
    oplWriteRegister(reg, val)
    
    // Sustain Level / Release Rate
    reg = 0x80 + slotOffset
    val = (instrument.modRelease & 15) |
      ((instrument.modSustain & 15) << 4)
    oplWriteRegister(reg, val)
    
    reg += 3
    val = (instrument.carrierRelease & 15) |
      ((instrument.carrierSustain & 15) << 4)
    oplWriteRegister(reg, val)
    
    // Panning / Feedback strength / Connection type
    // OPL3 mode requires bits 4-5 to be set for output:
    // - Bit 4 (0x10): Left channel enable
    // - Bit 5 (0x20): Right channel enable
    // Default to center panning (0x30 = both channels) for OPL3 mode
    reg = 0xC0 + UInt16(Int(channel) % herad.voicesSize)
    let panning: UInt8
    if player.opl3fm.isAdlibGold {
        panning = (instrument.panning == 0 || instrument.panning > 3) ? 3 : instrument.panning
    } else {
        // OPL3 mode: always enable both channels (center panning)
        panning = 3
    }
    val = (instrument.connector > 0 ? 0 : 1) |
      ((instrument.feedback & 7) << 1) |
      (panning << 4)
    oplWriteRegister(reg, val)
    
    // Wave Select
    reg = 0xE0 + slotOffset
    val = instrument.modWaveformSelect & (player.opl3fm.isAdlibGold ? 7 : 3)
    oplWriteRegister(reg, val)
    reg += 3
    
    val = instrument.carrierWaveformSelect & (player.opl3fm.isAdlibGold ? 7 : 3)
    oplWriteRegister(reg, val)
  }
  
  
  ///
  /// Sets frequency on the specified octave
  ///
  private func setFrequency(_ channel: UInt8, _ octave: UInt8, _ frequency: UInt16, _ isOn: Bool) {
    var reg: UInt16 = 0
    var val: UInt8 = 0
    
    reg = 0xA0 + UInt16(Int(channel) % herad.voicesSize)
    val = UInt8(frequency & 0xFF)
    oplWriteRegister(reg, val)
    
    reg = 0xB0 + UInt16(Int(channel) % herad.voicesSize)
    val = UInt8((frequency >> 8) & 3) | UInt8((octave & 7) << 2) | UInt8((isOn ? 1 : 0) << 5)
    oplWriteRegister(reg, val)
  }
  
  
  ///
  /// HERAD macro for mod output
  ///
  private func macroModOutput(_ channel: UInt8, _ instrument: HeradInstrument, _ direction: Int8, _ level: Int8) {
    var reg: UInt16 = 0
    var val: UInt8 = 0
    var output: UInt16 = 0
    
    if direction < -4 || direction > 4 {
      return
    }
    
    if direction < 0 {
      let value = Int16(level) >> (direction + 4)
      let result = (value > 63 ? 63 : value)
      output = UInt16(result)
    } else {
      // Parentheses required: subtraction must happen before shift
      let value = (0x80 - Int16(level)) >> (4 - direction)
      let result = (value > 63 ? 63 : value)
      output = UInt16(result)
    }

    output += UInt16(instrument.modOutputLevel)
    
    if output > 63 {
      output = 63
    }
    
    // Key scaling level / Output level
    let slotOffset = UInt16(herad.slotOffset[Int(channel) % herad.voicesSize])

    reg = 0x40 + slotOffset
    val = UInt8(output & 63) | ((instrument.modKeyScalingLevel & 3) << 6)
    oplWriteRegister(UInt16(reg), val)
  }


  ///
  /// HERAD macro for Carrier Output Level
  ///
  private func macroCarrierOutput(_ channel: UInt8, _ instrument: HeradInstrument, _ direction: Int8, _ level: Int8) {
    var reg: UInt16 = 0
    var val: UInt8 = 0
    var output: UInt16 = 0
    
    if direction < -4 || direction > 4 {
      return
    }

    if direction < 0 {
      let value = Int16(level) >> (direction + 4)
      let result = (value > 63 ? 63 : value)
      output = UInt16(result)
    } else {
      // Parentheses required: subtraction must happen before shift
      let value = (0x80 - Int16(level)) >> (4 - direction)
      let result = (value > 63 ? 63 : value)
      output = UInt16(result)
    }

    output += UInt16(instrument.carrierOutputLevel)
    
    if output > 63 {
      output = 63
    }

    // Key scaling level / Output level
    let slotOffset = UInt16(herad.slotOffset[Int(channel) % herad.voicesSize])

    reg = 0x43 + slotOffset
    val = UInt8(output & 63) | ((instrument.carrierKeyScalingLevel & 3) << 6)
    oplWriteRegister(UInt16(reg), val)
  }
  
  
  private func macroFeedback(_ channel: UInt8, _ instrument: HeradInstrument, _ direction: Int8, _ level: Int8) {
    var reg: UInt16 = 0
    var val: UInt8 = 0
    var feedback: UInt16 = 0
    
    if direction < -6 || direction > 6 {
      return
    }
    
    if direction < 0 {
      let value = level >> (direction + 7)
      let result = (value > 7 ? 7 : value)
      feedback = UInt16(result)
    } else {
      // Parentheses required: subtraction must happen before shift
      // Swift >> has higher precedence than -, opposite of C
      let value = (0x80 - Int16(level)) >> (7 - direction)
      let result = (value > 7 ? 7 : value)
      feedback = UInt16(result)
    }

    feedback += UInt16(instrument.feedback)
    
    if feedback > 7 {
      feedback = 7
    }
    
    // Panning / Feedback strength / Connection type
    // OPL3 mode requires bits 4-5 for channel output enable
    reg = 0xC0 + UInt16(Int(channel) % herad.voicesSize)
    let panValue: UInt8
    if player.opl3fm.isAdlibGold {
        panValue = (instrument.panning == 0 || instrument.panning > 3) ? 3 : instrument.panning
    } else {
        // OPL3 mode: enable both channels (center panning)
        panValue = 3
    }
    val = (instrument.connector > 0 ? 0 : 1) | UInt8((feedback & 0x7) << 1) | (panValue << 4)
    oplWriteRegister(UInt16(reg), val)
  }
  
  
  ///
  /// HERAD macro for note transposition
  /// This is HERAD v1 specific (used by Dune)
  ///
  private func macroTranspose(_ note: inout UInt8, _ instrument: HeradInstrument) {
    let transpose = instrument.rootNodeTranspose
    //let diff = (transpose - 0x31) & 0xFF
    note = UInt8((UInt16(note) + UInt16(transpose)) & 0xFF)
  }
  
  
  ///
  /// HERAD macro for slide
  ///
  private func macroSlide(_ channelIndex: UInt8) {
    let idx = Int(channelIndex)

    if herad.channels[idx].pitchSlideDuration == 0 {
      return
    }

    herad.channels[idx].pitchSlideDuration -= 1

    // Wrapping addition: pitchSlideRange is Int8 (can be negative), bend is UInt8
    // In C this wraps silently; in Swift we use &+ with bitPattern conversion
    let slideRange = herad.channels[idx].playProgram!.pitchSlideRange
    herad.channels[idx].bend = herad.channels[idx].bend &+ UInt8(bitPattern: slideRange)

    if (herad.channels[idx].note & 0x7F) == 0 {
      return
    }

    playNote(channelIndex, herad.channels[idx].note, .noteUpdate)
  }
  
  
  func dumpInfo() {
    engine.logger.log(.debug, herad.debugDescription)
  }
}


// MARK: MIDI conversion
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
      /*case .aftertouch(let note, let value, let channel):
        break*/
      default:
        break
    }
  }
}
