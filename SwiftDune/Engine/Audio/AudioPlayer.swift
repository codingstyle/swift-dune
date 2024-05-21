//
//  AudioPlayer.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 29/08/2023.
//

import Foundation
import AVFoundation

class AudioPlayer {
    var audioEngine = AVAudioEngine()

    init() {
        initAudioEngine()
    }

    
    private func initAudioEngine() {
        // Start the audio engine
         do {
             let outputAudioFormat = audioEngine.mainMixerNode.outputFormat(forBus: 0)
             audioEngine.connect(audioEngine.mainMixerNode, to: audioEngine.outputNode, format: outputAudioFormat)
             audioEngine.prepare()
             try audioEngine.start()
        } catch {
            print("Error starting the audio engine: \(error.localizedDescription)")
        }
    }
    
    func playSound(_ sound: Sound) throws {
        print("Playing sound: \(sound.resource.fileName)")

        var currentSampleRate: Double = 0
        var playerNode = AVAudioPlayerNode()

        let pcmBlocks = sound.asPCMBlocks()
        
        for i in 0..<pcmBlocks.count {
            let pcmBuffer = pcmBlocks[i].asPCMBuffer()

            if pcmBuffer!.format.sampleRate != currentSampleRate {
                currentSampleRate = pcmBuffer!.format.sampleRate
                
                playerNode = AVAudioPlayerNode()
                audioEngine.attach(playerNode)
                audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: AVAudioFormat(standardFormatWithSampleRate: currentSampleRate, channels: 1))
            }
            
            playerNode.scheduleBuffer(pcmBuffer!)
            playerNode.play()
        }
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
        
        for i in 0..<dataBlocks.count {
            switch dataBlocks[i] {
            case .terminate:
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
            case .endRepetition:
                var pcmBuffer: [UInt8] = []
                
                for _ in 0..<repeatCount {
                    pcmBuffer.append(contentsOf: repeatBuffer)
                }

                pcmBlocks.append(SoundPCMBlock(codec: currentCodec, samplingRate: CGFloat(currentSamplingRate), bytes: pcmBuffer))
                
                isRepeating = false
                repeatCount = 0
                repeatBuffer = []
            case .silence(let codec, let length, let samplingRate):
                pcmBlocks.append(SoundPCMBlock(codec: codec, samplingRate: CGFloat(samplingRate), bytes: [UInt8](repeating: 0, count: Int(length))))
            case .string(_):
                break
            case .marker(_):
                break
            }
        }
        
        return pcmBlocks
    }
}


struct SoundPCMBlock {
    var codec: VOCAudioCodec
    var samplingRate: CGFloat
    var bytes: [UInt8]
    
    func saveAsWAV(_ fileName: String) {
        var waveBytes: [UInt8] = []

        let rate = UInt32(samplingRate)
        let fileSize = UInt32(bytes.count) - 8
        let blockSize = UInt32(bytes.count) - 16
        let dataSize = UInt32(bytes.count) - 44 // Header size is 44 bytes

        waveBytes.append(contentsOf: [0x52, 0x49, 0x46, 0x46]) // "RIFF"
        
        // File Size - 8 bytes
        waveBytes.append(contentsOf: [UInt8(fileSize & 0xFF), UInt8((fileSize >> 8) & 0xFF), UInt8((fileSize >> 16) & 0xFF), UInt8(fileSize >> 24)])
        waveBytes.append(contentsOf: [0x57, 0x41, 0x56, 0x45]) // "WAVE"
        waveBytes.append(contentsOf: [0x66, 0x6D, 0x74, 0x20]) // "fmt "
        // Block size - 0x10
        waveBytes.append(contentsOf: [UInt8(blockSize & 0xFF), UInt8((blockSize >> 8) & 0xFF), UInt8((blockSize >> 16) & 0xFF), UInt8(blockSize >> 24)])
        waveBytes.append(contentsOf: [0x01, 0x00]) // Format (1 = PCM integer)
        waveBytes.append(contentsOf: [0x01, 0x00]) // Number of channels (1)
        // Sampling rate
        waveBytes.append(contentsOf: [UInt8(rate & 0xFF), UInt8((rate >> 8) & 0xFF), UInt8((rate >> 16) & 0xFF), UInt8(rate >> 24)])
        // Bytes per second (= sampling rate * bytes per block)
        waveBytes.append(contentsOf: [UInt8(rate & 0xFF), UInt8((rate >> 8) & 0xFF), UInt8((rate >> 16) & 0xFF), UInt8(rate >> 24)])
        waveBytes.append(contentsOf: [0x01, 0x00]) // Bytes per block (1)
        waveBytes.append(contentsOf: [0x08, 0x00]) // Bits per channel (8)

        waveBytes.append(contentsOf: [0x64, 0x61, 0x74, 0x61]) // "data"
        waveBytes.append(contentsOf: [UInt8(dataSize & 0xFF), UInt8((dataSize >> 8) & 0xFF), UInt8((dataSize >> 16) & 0xFF), UInt8(dataSize >> 24)])
        waveBytes.append(contentsOf: bytes)
        
        let downloadsDirectory = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        let fileURL = downloadsDirectory.appendingPathComponent(fileName)
        let data = Data(waveBytes)
        
        do {
            try data.write(to: fileURL)
            print("WAV data saved to file: \(fileURL.absoluteString)")
        } catch {
            print("Error saving \(fileName): \(error)")
        }
    }
    
    
    func asPCMBuffer() -> AVAudioPCMBuffer? {
        let sample = convert8to16BitPCM(bytes)
        let data = Data(bytes: sample, count: MemoryLayout<Int16>.size)

        let format = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: samplingRate, channels: 1, interleaved: false)!
        
        let frameCapacity = AVAudioFrameCount(UInt32(data.count) / 2)
        guard let audioBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCapacity) else { return nil }
        audioBuffer.frameLength = frameCapacity
        
        let dest = audioBuffer.int16ChannelData![0]

        sample.withUnsafeBytes { bufferPointer in
            let addr: UnsafePointer<Int16> = bufferPointer.baseAddress!.assumingMemoryBound(to: Int16.self)
            dest.initialize(from: addr, count: Int(frameCapacity))
        }
        
        /*let bufferChannels = audioBuffer.int16ChannelData!
        let bufferDataCount = data.copyBytes(to: UnsafeMutableBufferPointer(start: bufferChannels[0], count: Int(frameCapacity)))
         */
        /*bytes.withUnsafeBytes { bufferPointer in
            let addr: UnsafePointer<UInt8> = bufferPointer.baseAddress!.assumingMemoryBound(to: UInt8.self)
            memcpy(audioBuffer.mutableAudioBufferList.pointee.mBuffers.mData, addr, Int(frameCapacity))
        }*/
        
        return audioBuffer
      }
    
    func convert8to16BitPCM(_ eightBitData: [UInt8]) -> [Int16] {
        var sixteenBitData = [Int16]()
        var i = 0
        
        // Convert unsinged 8-bit sample to signed 16-bit PCM sample
        while i < eightBitData.count {
            let sixteenBitSample = Int16((Int(eightBitData[i]) << 8) - 32768)
            sixteenBitData.append(sixteenBitSample)
        }
        
        return sixteenBitData
    }
}
