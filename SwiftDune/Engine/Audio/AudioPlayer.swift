//
//  AudioPlayer.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 29/08/2023.
//

import Foundation
import AVFoundation

protocol AudioPlayerItem {
  var type: AudioPlayerItemType { get }
  
  init(_ fileName: String, player: AudioPlayer)
  func play()
  func stop()
  func dumpInfo()
}

enum AudioPlayerItemType {
  case music
  case sound
}


final class AudioPlayer {
    private let audioEngine = AVAudioEngine()
    private var currentPlayerItem: AudioPlayerItem?
  
    private let soundFxNode = AVAudioPlayerNode()
    private let soundFxMixerNode = AVAudioMixerNode()
    private let soundFxAudioFormat = AVAudioFormat(standardFormatWithSampleRate: 22500.0, channels: 1)!
  
    private let musicMaxTracks = 21
    private var musicSamplerNode: [AVAudioUnitSampler] = []
    private let musicMixerNode = AVAudioMixerNode()

    private let opl = OPL3()
    private let oplNode = AVAudioPlayerNode()
    private let oplMixerNode = AVAudioMixerNode()
    private let oplAudioFormat = AVAudioFormat(standardFormatWithSampleRate: 22500.0, channels: 2)!

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
          audioEngine.mainMixerNode.outputVolume = 0.1  // Increased from 0.1 to 1.0
          audioEngine.connect(audioEngine.mainMixerNode, to: audioEngine.outputNode, format: outputAudioFormat)
          
          // Sound FX nodes with 11500 Hz sample rate
          audioEngine.attach(soundFxNode)
          audioEngine.attach(soundFxMixerNode)
          audioEngine.connect(soundFxNode, to: soundFxMixerNode, format: soundFxAudioFormat)
          audioEngine.connect(soundFxMixerNode, to: audioEngine.mainMixerNode, format: nil)
        
          // OPL node
          audioEngine.attach(oplNode)
          audioEngine.attach(oplMixerNode)
          oplMixerNode.outputVolume = 1.0  // Ensure OPL mixer is at full volume
          audioEngine.connect(oplNode, to: oplMixerNode, format: oplAudioFormat)
          audioEngine.connect(oplMixerNode, to: audioEngine.mainMixerNode, format: nil)
          
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
  
  
    func node(for type: AudioPlayerItemType) -> AVAudioPlayerNode {
      switch type {
        case .music:
          return oplNode
        
        case .sound:
          return soundFxNode
      }
    }
  
  
    func play(_ item: AudioPlayerItem) {
      if let currentPlayerItem = currentPlayerItem {
        currentPlayerItem.stop()
      }
      
      self.currentPlayerItem = item
      item.play()
    }
  
  
    func stop() {
      if let currentPlayerItem = currentPlayerItem {
        currentPlayerItem.stop()
      }
      
      self.currentPlayerItem = nil
    }
    
    
    public func resampledBuffer(_ sourceBuffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
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
