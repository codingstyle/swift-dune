//
//  AudioPlayer.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 29/08/2023.
//

import Foundation
import AVFoundation

final class AudioPlayer {
    private let audioEngine = AVAudioEngine()
    private let soundFxNode = AVAudioPlayerNode()
    private let soundFxMixerNode = AVAudioMixerNode()
    private let soundFxAudioFormat = AVAudioFormat(standardFormatWithSampleRate: 22500.0, channels: 1)!
  
    private let musicMaxTracks = 21
    private var musicSamplerNode: [AVAudioUnitSampler] = []
    private let musicMixerNode = AVAudioMixerNode()
    private var currentMusicTicks = 0
    private var musicTimer: Timer?
    private var isMusicPlaying: Bool = false

    init() {
        initAudioEngine()
    }
    
    deinit {
        destroyAudioEngine()
    }

    
    private func initAudioEngine() {
        // Start the audio engine
      do {
          // Attach mixer
          let outputAudioFormat = audioEngine.mainMixerNode.outputFormat(forBus: 0)
          audioEngine.mainMixerNode.outputVolume = 0.1
          audioEngine.connect(audioEngine.mainMixerNode, to: audioEngine.outputNode, format: outputAudioFormat)
          
          // Sound FX nodes with 11500 Hz sample rate
          audioEngine.attach(soundFxNode)
          audioEngine.attach(soundFxMixerNode)
          audioEngine.connect(soundFxNode, to: soundFxMixerNode, format: soundFxAudioFormat)
          audioEngine.connect(soundFxMixerNode, to: audioEngine.mainMixerNode, format: nil)
   
          // Music sampler nodes
          for i in 0..<musicMaxTracks {
            let samplerNode = AVAudioUnitSampler()
            musicSamplerNode.append(samplerNode)
            audioEngine.attach(musicSamplerNode[i])
          }
          
          audioEngine.attach(musicMixerNode)

          for i in 0..<musicMaxTracks {
            audioEngine.connect(musicSamplerNode[i], to: musicMixerNode, format: nil)
          }

          audioEngine.connect(musicMixerNode, to: audioEngine.mainMixerNode, format: nil)

          audioEngine.prepare()
          try audioEngine.start()

          print("[AudioPlayer] Engine started.")
        } catch {
            print("Error starting the audio engine: \(error.localizedDescription)")
        }
    }
    
    
    private func destroyAudioEngine() {
        audioEngine.stop()
        audioEngine.attachedNodes.forEach { node in
            audioEngine.detach(node)
        }
        
        print("[AudioPlayer] Engine stopped.")
    }
    
    
    func play(_ sound: Sound) {
        if soundFxNode.isPlaying {
          soundFxNode.stop()
        }

        print("Playing sound: \(sound.resource.fileName)")

        var i = 0
        
        var pendingBuffers: [AVAudioPCMBuffer] = []
        var isRepeating = false
        var repeatCount = 1

        while i < sound.dataBlocks.count {
            let dataBlock = sound.dataBlocks[i]
            
            switch dataBlock {
            case .endRepetition:
                isRepeating = false
                break
            case .terminate:
                isRepeating = false
                break
            case .soundData(_, _, _):
                let resampledBuffer = resampledBuffer(dataBlock.asPCMBuffer!)
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
            
            if isRepeating {
                i += 1
                continue
            }
            
            soundFxNode.scheduleBuffersLoop(pendingBuffers, numberOfLoops: repeatCount)
            soundFxNode.play()
            
            i += 1
            
            repeatCount = 1
            pendingBuffers = []
        }
        
        // print("[AudioPlayer] Audio graph = \(audioEngine.debugDescription)")
    }
  
  
    func play(_ music: Music) {
      stop(music)
      self.isMusicPlaying = true
      
      self.musicTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / music.ticksPerSecond, repeats: true, block: { _ in
        var i = 0
        
        while i < music.tracks.count {
          let track = music.tracks[i]
          let event = track.event(at: self.currentMusicTicks)
          
          if let event = event {
            self.musicSamplerNode[i].playHeradEvent(event)
          }
          
          i += 1
        }

        self.currentMusicTicks += 1
      })
    }
  
  
    func stop(_ music: Music) {
      if !self.isMusicPlaying { return }
      
      self.currentMusicTicks = 0
      
      if self.musicTimer != nil {
        self.musicTimer!.invalidate()
        self.musicTimer = nil
      }
      
      self.isMusicPlaying = false
    }
    
    
    private func resampledBuffer(_ sourceBuffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        let frameCapacity = AVAudioFrameCount(CGFloat(sourceBuffer.frameCapacity) * (soundFxAudioFormat.sampleRate / sourceBuffer.format.sampleRate))
        guard let destBuffer = AVAudioPCMBuffer(pcmFormat: soundFxAudioFormat, frameCapacity: frameCapacity) else { return nil }
        
        var error: NSError?
        
        let converter = AVAudioConverter(from: sourceBuffer.format, to: soundFxAudioFormat)!
        let outputStatus = converter.convert(to: destBuffer, error: &error) { numberOfFrames, inputStatus in
            inputStatus.pointee = .haveData
            return sourceBuffer
        }
        
        if outputStatus == .error {
            if let error = error {
                print("[AudioPlayer] Error resampling: \(error.localizedDescription)")
            }
        }
        
        return destBuffer
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
              break
            case .aftertouch(let note, let value, let channel):
              break
            default:
              break
        }
    }
}



extension AVAudioPlayerNode {
    func scheduleBuffersLoop(_ buffers: [AVAudioPCMBuffer], numberOfLoops: Int = 1) {
        if numberOfLoops == 0xFFFF {
            scheduleBuffer(buffers[0], at: nil, options: .loops)
            return
        }
        
        var n = 0
        
        while n < numberOfLoops {
            var i = 0
            
            while i < buffers.count {
                scheduleBuffer(buffers[i], at: nil)
                i += 1
            }

            n += 1
        }
    }
}
