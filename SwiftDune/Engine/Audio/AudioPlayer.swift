//
//  AudioPlayer.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 29/08/2023.
//

import Foundation
import AVFoundation

class AudioPlayer {
    private var audioEngine = AVAudioEngine()
    private var playerNode = AVAudioPlayerNode()
    private var playerAudioFormat = AVAudioFormat(standardFormatWithSampleRate: 22500.0, channels: 1)!

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

            // Attach player node with 11500 Hz sample rate
            audioEngine.attach(playerNode)
            audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: playerAudioFormat)

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
        if playerNode.isPlaying {
            playerNode.stop()
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
            
            playerNode.scheduleBuffersLoop(pendingBuffers, numberOfLoops: repeatCount)
            playerNode.play()
            i += 1
            
            repeatCount = 1
            pendingBuffers = []
        }
        
        // print("[AudioPlayer] Audio graph = \(audioEngine.debugDescription)")
    }
    
    
    private func resampledBuffer(_ sourceBuffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        let frameCapacity = AVAudioFrameCount(CGFloat(sourceBuffer.frameCapacity) * (playerAudioFormat.sampleRate / sourceBuffer.format.sampleRate))
        guard let destBuffer = AVAudioPCMBuffer(pcmFormat: playerAudioFormat, frameCapacity: frameCapacity) else { return nil }
        
        var error: NSError?
        
        let converter = AVAudioConverter(from: sourceBuffer.format, to: playerAudioFormat)!
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
