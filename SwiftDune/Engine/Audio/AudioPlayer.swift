//
//  DuneAudioPlayer.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 11/10/2026.
//


protocol AudioPlayerItem {
  var type: AudioPlayerItemType { get }
  var fileName: String { get }
  
  init(_ fileName: String, player: AudioPlayer)
  func play(loop: Bool)
  func stop()
  func dumpInfo()
}

enum AudioPlayerItemType {
  case music
  case sound
}


class AudioPlayer {
    private var currentAudioItem: AudioPlayerItem?
    private var currentMusicItem: AudioPlayerItem?

    /// OPL3 FM Synthesizer (NukedOPL3 implementation)
    let opl3fm = OPL3Fm(bufferSize: 4096)
  
    /// Native OPL3 rate. The chip resamples from this rate to `oplSampleRate`.
    static let nativeOPLSampleRate: Double = 49716.0

    /// Sample rate of the frames written for playback.
    /// macOS keeps the native OPL3 rate. iOS sets the hardware rate so the graph does not resample.
    var oplSampleRate: Double = AudioPlayer.nativeOPLSampleRate
    
    /// Number of OPL3 samples per HERAD tick - set by Music before calling startOPL3()
    var oplSamplesPerTick: Double = 0
    
    /// Callback invoked at each HERAD tick boundary during audio generation.
    /// Should process events for the current tick. Returns false when music is finished.
    var oplTickCallback: (() -> Bool)?
    
    /// Countdown of samples until the next tick boundary
    var oplSamplesUntilNextTick: Double = 0
  
  
    init() {
      
    }
  
  
    deinit {
      
    }

  
    func startOPL3() {
        // OPL3Fm handles tone generator initialization in reset()
        // Use direct writes (not buffered) for initial setup
        opl3fm.reset(UInt32(oplSampleRate.rounded()))
        opl3fm.writeRegister(0x105, 1) // Enable OPL3
        opl3fm.writeRegister(0x104, 0) // Disable 4OP Mode
    }

  
    func stopOPL3() {
        // Apply while the generator is stopped. Queued writes would sit until the
        // next play and run ahead of that song's program changes.
        opl3fm.writeRegisterDirect(0x08, 64)   // Enable Note-Sel
        opl3fm.writeRegisterDirect(0x23, 238)  // Tremolo/Vibrato/etc
        opl3fm.writeRegisterDirect(0xBD, 0)    // Disable Percussion Mode
    }
  
  
    func queueSoundBuffers(_ buffers: [PCMBuffer], numberOfLoops: Int) {

    }
  
  
    func playSong(_ name: String, loop: Bool = true) {
        if currentMusicItem != nil && currentMusicItem?.fileName == name {
            return
        }
      
        let item = Music(name, player: self)
        self.play(item, loop: loop)
    }

  
    func playSound(_ name: String, loop: Bool = false) {
        if currentAudioItem != nil && currentAudioItem?.fileName == name {
            return
        }

        let item = Sound(name, player: self)
        self.play(item, loop: loop)
    }


    func play(_ item: AudioPlayerItem, loop: Bool = false) {
        if item.type == .sound {
            if let currentAudioItem = currentAudioItem {
              currentAudioItem.stop()
            }
            
            self.currentAudioItem = item
        } else if item.type == .music {
            if let currentMusicItem = currentMusicItem {
              currentMusicItem.stop()
            }
            
            self.currentMusicItem = item
        }
        
        item.play(loop: loop)
    }
  
  
    func stopSound() {
        if let currentAudioItem = currentAudioItem {
          currentAudioItem.stop()
        }
        
        self.currentAudioItem = nil
    }
  
  
    func stopMusic() {
        if let currentMusicItem = currentMusicItem {
          currentMusicItem.stop()
        }
        
        self.currentMusicItem = nil
    }
    
    
    func stop() {
        stopSound()
        stopMusic()
    }
}
