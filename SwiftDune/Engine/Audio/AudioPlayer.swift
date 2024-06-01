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

    init() {
        initAudioEngine()
    }
    
    deinit {
        destroyAudioEngine()
    }

    
    private func initAudioEngine() {
        // Start the audio engine
         do {
             let outputAudioFormat = audioEngine.mainMixerNode.outputFormat(forBus: 0)
             audioEngine.mainMixerNode.volume = 0.5
             audioEngine.mainMixerNode.outputVolume = 0.5
             audioEngine.connect(audioEngine.mainMixerNode, to: audioEngine.outputNode, format: outputAudioFormat)
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
        print("Playing sound: \(sound.resource.fileName)")

        var currentSampleRate: Double = 0
        let pcmBlocks = sound.asPCMBlocks()
        
        var i = 0
        
        print("[AudioPlayer] PCM blocks count: \(pcmBlocks.count)")

        var playerNode: AVAudioPlayerNode?

        while i < pcmBlocks.count {
            let pcmBuffer = pcmBlocks[i].asPCMBuffer()
            
            print("[AudioPlayer] PCM buffer #\(i): samplingRate=\(pcmBlocks[i].samplingRate), codec=\(pcmBlocks[i].codec), byteCount=\(pcmBlocks[i].bytes.count)")

            if playerNode != nil || pcmBuffer!.format.sampleRate != currentSampleRate {
                currentSampleRate = pcmBuffer!.format.sampleRate

                if playerNode != nil {
                    audioEngine.detach(playerNode!)
                    playerNode = nil
                }

                // let format = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: currentSampleRate, channels: 1, interleaved: false)
                let format = AVAudioFormat(standardFormatWithSampleRate: currentSampleRate, channels: 1)
                playerNode = AVAudioPlayerNode()
                audioEngine.attach(playerNode!)
                audioEngine.connect(playerNode!, to: audioEngine.mainMixerNode, format: format)
            }
            
            playerNode!.scheduleBuffer(pcmBuffer!)
            playerNode!.play()
            i += 1
        }
        
        // print("[AudioPlayer] Audio graph = \(audioEngine.debugDescription)")
    }
}


extension Sound {
    func asPCMBlocks() -> [SoundPCMBlock] {
        var pcmBlocks: [SoundPCMBlock] = []
        
        var isRepeating = false
        var repeatCount: UInt16 = 0
        var repeatBuffer: [UInt8] = []
        var currentSamplingRate: UInt16 = 0
        var currentCodec: VOCAudioCodec = .unsigned8bitPCM
        var i = 0
        
        while i < dataBlocks.count {
            switch dataBlocks[i] {
            case .terminate:
                if isRepeating {
                    var pcmBuffer: [UInt8] = []
                    var n = 0
                    
                    while n < repeatCount {
                        pcmBuffer.append(contentsOf: repeatBuffer)
                        n += 1
                    }
                    
                    pcmBlocks.append(SoundPCMBlock(codec: currentCodec, samplingRate: CGFloat(currentSamplingRate), bytes: repeatBuffer))
                    isRepeating = false
                }
                
                break
            case .soundData(let codec, let samplingRate, let bytes):
                currentSamplingRate = samplingRate
                currentCodec = codec
                
                if isRepeating {
                    repeatBuffer.append(contentsOf: bytes)
                } else {
                    pcmBlocks.append(SoundPCMBlock(codec: codec, samplingRate: CGFloat(samplingRate), bytes: bytes))
                }
                break
            case .repetition(let count):
                isRepeating = true
                repeatCount = count
                break
            case .endRepetition:
                var pcmBuffer: [UInt8] = []
                var n = 0
                
                while n < repeatCount {
                    pcmBuffer.append(contentsOf: repeatBuffer)
                    n += 1
                }

                pcmBlocks.append(SoundPCMBlock(codec: currentCodec, samplingRate: CGFloat(currentSamplingRate), bytes: pcmBuffer))
                
                isRepeating = false
                repeatCount = 0
                repeatBuffer = []
                break
            case .silence(let codec, let length, let samplingRate):
                pcmBlocks.append(SoundPCMBlock(codec: codec, samplingRate: CGFloat(samplingRate), bytes: [UInt8](repeating: 0, count: Int(length))))
                break
            case .string(_):
                break
            case .marker(_):
                break
            }
            
            i += 1
        }
        
        return pcmBlocks
    }
}


struct SoundPCMBlock {
    var codec: VOCAudioCodec
    var samplingRate: CGFloat
    var bytes: [UInt8]
    
    func asPCMBuffer() -> AVAudioPCMBuffer? {
        let sample = convertUInt8ToFloat32PCM(bytes)
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: samplingRate, channels: 1, interleaved: false)!
        
        let frameCapacity = AVAudioFrameCount(UInt32(sample.count))
        guard let audioBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCapacity) else { return nil }
        
        memcpy(audioBuffer.mutableAudioBufferList.pointee.mBuffers.mData, sample, sample.count * MemoryLayout<Float32>.size)
        audioBuffer.frameLength = frameCapacity
        
        return audioBuffer
    }
    
    
    private func convertUInt8ToFloat32PCM(_ eightBitData: [UInt8]) -> [Float32] {
        var floatData = [Float32]()
        var i = 0
        
        // Convert sample from unsigned 8-bit to signed 16-bit PCM
        while i < eightBitData.count {
            let tempData = Int16(eightBitData[i]) - 0x80
            let floatSample = Float32(tempData << 8) / 256.0
            floatData.append(floatSample)
            i += 1
        }
        
        return floatData
    }
}
