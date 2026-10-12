//
//  AudioPlayer.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 29/08/2023.
//

import Foundation
import AVFoundation

#if os(iOS)
import AVFAudio
#endif

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


final class AudioPlayer {
    private let audioEngine = AVAudioEngine()

    private var currentAudioItem: AudioPlayerItem?
    private var currentMusicItem: AudioPlayerItem?
  
    private let soundFxNode = AVAudioPlayerNode()
    private let soundFxMixerNode = AVAudioMixerNode()
    private let soundFxAudioFormat = AVAudioFormat(standardFormatWithSampleRate: 22500.0, channels: 1)!
  
    private let musicMaxTracks = 21
    private var musicSamplerNode: [AVAudioUnitSampler] = []
    private let musicMixerNode = AVAudioMixerNode()

    /// OPL3 FM Synthesizer (NukedOPL3 implementation)
    let opl3fm = OPL3Fm(bufferSize: 4096)

    private let oplNode = AVAudioPlayerNode()
    private let oplMixerNode = AVAudioMixerNode()
    /// Set in initAudioEngine to the hardware rate on iOS so the mixer does not resample.
    private var oplAudioFormat: AVAudioFormat!
    
    /// Audio generation timer. macOS only; iOS refills from the player queue instead.
    private var oplTimer: DispatchSourceTimer?
    private let oplQueue = DispatchQueue(label: "com.swiftdune.opl3", qos: .userInteractive)
    private let oplQueueKey = DispatchSpecificKey<UInt8>()
    /// Set when playback is stopped from inside buffer generation, so the buffer is not scheduled afterward.
    private var oplStopped = false
#if os(iOS)
    /// True while a start/refill cycle owns the OPL queue.
    private var oplRunning = false
    /// Bumped on start and stop so a completion from an old playback cannot refill the new one.
    private var oplGeneration: UInt = 0
    /// Buffers currently sitting in AVAudioPlayerNode.
    private var oplScheduledBufferCount = 0
    /// 4 × 8192 frames is about 660 ms at 49716 Hz. Debug synthesis on device often needs
    /// most of that lead; the macOS timer's 45 ms gap underruns before the next buffer exists.
    private let oplScheduledBufferTarget = 4
#endif
  
    init() {
        oplQueue.setSpecific(key: oplQueueKey, value: 1)
        initAudioEngine()
    }
    
    deinit {
        destroyAudioEngine()
    }

    
    private func initAudioEngine() {
        // Start the audio engine
      do {
#if os(iOS)
          let session = AVAudioSession.sharedInstance()
          try session.setCategory(.playback, mode: .default, options: [])
          try session.setPreferredSampleRate(48_000)
          try session.setPreferredIOBufferDuration(0.02) // 20 ms
          try session.setActive(true)
          // Match the hardware clock. A 49716 → 48000 converter in the graph slips every few seconds.
          let hardwareRate = audioEngine.outputNode.outputFormat(forBus: 0).sampleRate
          Self.oplSampleRate = hardwareRate > 0 ? hardwareRate : 48_000
#endif
          oplAudioFormat = AVAudioFormat(standardFormatWithSampleRate: Self.oplSampleRate, channels: 2)!
        
          // Attach mixer
          let outputAudioFormat = audioEngine.mainMixerNode.outputFormat(forBus: 0)
          audioEngine.mainMixerNode.outputVolume = 1.0  // Increased from 0.1 to 1.0
          audioEngine.connect(audioEngine.mainMixerNode, to: audioEngine.outputNode, format: outputAudioFormat)
          
          // Sound FX nodes with 11500 Hz sample rate
          audioEngine.attach(soundFxNode)
          audioEngine.attach(soundFxMixerNode)
          soundFxMixerNode.outputVolume = 0.5
          audioEngine.connect(soundFxNode, to: soundFxMixerNode, format: soundFxAudioFormat)
          audioEngine.connect(soundFxMixerNode, to: audioEngine.mainMixerNode, format: nil)
        
          // OPL3 init
          initOPL3()
        
          // OPL3 node setup
          audioEngine.attach(oplNode)
          audioEngine.attach(oplMixerNode)
          oplMixerNode.outputVolume = 1.0
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
  
    
    private func initOPL3() {
        // OPL3Fm handles tone generator initialization in reset()
        // Use direct writes (not buffered) for initial setup
        opl3fm.reset(UInt32(Self.oplSampleRate.rounded()))
        opl3fm.writeRegister(0x105, 1) // Enable OPL3
        opl3fm.writeRegister(0x104, 0) // Disable 4OP Mode
    }
  
    /// Number of samples per buffer (at 49716 Hz, 8192 samples = ~165ms)
    /// Larger buffers reduce timer overhead and allocation frequency
    private let oplBufferFrameCount = 8192

    /// Pre-allocated buffer pool to avoid per-timer-fire heap allocation
    private var oplBufferPool: [AVAudioPCMBuffer] = []
    
    /// OPL3 output rate. 49716 Hz on macOS; the active hardware rate on iOS.
    static var oplSampleRate: Double = 49716.0
    
    /// Number of OPL3 samples per HERAD tick - set by Music before calling startOPL3()
    var oplSamplesPerTick: Double = 0
    
    /// Callback invoked at each HERAD tick boundary during audio generation.
    /// Should process events for the current tick. Returns false when music is finished.
    var oplTickCallback: (() -> Bool)?
    
    /// Countdown of samples until the next tick boundary
    private var oplSamplesUntilNextTick: Double = 0
    
    /// Gets a buffer from the pool or creates a new one
    private func acquireOPL3Buffer() -> AVAudioPCMBuffer {
        if let buffer = oplBufferPool.popLast() {
            buffer.frameLength = AVAudioFrameCount(oplBufferFrameCount)
            return buffer
        }
        let buffer = AVAudioPCMBuffer(pcmFormat: oplAudioFormat, frameCapacity: AVAudioFrameCount(oplBufferFrameCount))!
        buffer.frameLength = AVAudioFrameCount(oplBufferFrameCount)
        return buffer
    }

    /// Returns a buffer to the pool for reuse
    private func releaseOPL3Buffer(_ buffer: AVAudioPCMBuffer) {
        oplBufferPool.append(buffer)
    }

    /// Starts OPL3 generation on the audio queue. Returns immediately so the caller is not blocked
    /// while the first buffer is synthesized.
    func startOPL3() {
        oplQueue.async { [weak self] in
            self?.startOPL3OnQueue()
        }
    }

    private func startOPL3OnQueue() {
#if os(iOS)
        guard !oplRunning else { return }

        oplRunning = true
        oplStopped = false
        oplGeneration &+= 1
        oplScheduledBufferCount = 0
        // Start at 0 so the first tick (tick 0) is processed immediately
        oplSamplesUntilNextTick = 0

        // One buffer per queue turn, so stop() is not stuck behind the whole lead.
        // Playback starts only after the lead is full.
        produceOPL3Buffer()
#else
        guard oplTimer == nil else { return }

        oplStopped = false
        // Start at 0 so the first tick (tick 0) is processed immediately
        oplSamplesUntilNextTick = 0

        // One buffer (~165ms) is enough to start. The timer keeps playback ahead after that.
        generateAndScheduleOPL3Buffer()

        guard !oplStopped else { return }

        if !oplNode.isPlaying {
            oplNode.play()
        }

        // Timer: generate new buffer every ~120ms
        // Each buffer is ~165ms at 49716 Hz, so we stay well ahead of playback
        let timer = DispatchSource.makeTimerSource(queue: oplQueue)
        timer.schedule(deadline: .now() + .milliseconds(120), repeating: .milliseconds(120), leeway: .milliseconds(5))

        timer.setEventHandler { [weak self] in
            self?.generateAndScheduleOPL3Buffer()
        }

        timer.resume()
        oplTimer = timer
#endif
    }

#if os(iOS)
    /// Fills the lead. Before playback starts, each buffer yields so stop() can run between them.
    /// Once playback is running, a deficit is filled in one turn so a stall can be caught up.
    /// Called on the OPL queue.
    private func produceOPL3Buffer() {
        guard oplRunning, !oplStopped else { return }

        while oplRunning && !oplStopped && oplScheduledBufferCount < oplScheduledBufferTarget {
            guard generateAndScheduleOPL3Buffer() else { break }

            if !oplNode.isPlaying {
                oplQueue.async { [weak self] in
                    self?.produceOPL3Buffer()
                }
                return
            }
        }

        if oplScheduledBufferCount > 0, oplRunning, !oplStopped, !oplNode.isPlaying {
            oplNode.play()
        } else if oplScheduledBufferCount == 0 {
            oplRunning = false
        }
    }
#endif
    
    /// Stops the OPL3 audio generation timer.
    /// Synchronous when called off the audio queue so a following play() cannot be wiped by a late stop.
    /// Inline when already on the queue: the tick callback stops playback from inside generation.
    func stopOPL3() {
        if DispatchQueue.getSpecific(key: oplQueueKey) != nil {
            stopOPL3OnQueue()
        } else {
            oplQueue.sync {
                stopOPL3OnQueue()
            }
        }
    }

    private func stopOPL3OnQueue() {
        oplStopped = true
#if os(iOS)
        oplRunning = false
        oplGeneration &+= 1
        oplScheduledBufferCount = 0
#endif
        oplTimer?.cancel()
        oplTimer = nil
        oplTickCallback = nil
        oplNode.stop()
        opl3fm.silence()
        oplBufferPool.removeAll()
    }
    
    /// Generates audio samples and schedules them for playback.
    /// Events are processed at tick boundaries within the buffer for correct timing.
    /// Returns false when playback was stopped or the buffer could not be filled.
    @discardableResult
    private func generateAndScheduleOPL3Buffer() -> Bool {
        let buffer = acquireOPL3Buffer()

        guard let leftChannel = buffer.floatChannelData?[0],
              let rightChannel = buffer.floatChannelData?[1] else {
            return false
        }

        let scale: Float = 1.0 / Float(Int16.max)
        var frame = 0

        while frame < oplBufferFrameCount {
            // Process tick events at boundaries
            if oplSamplesUntilNextTick <= 0 {
                if let callback = oplTickCallback {
                    if !callback() {
                        // Music finished - fill remaining frames with silence
                        while frame < oplBufferFrameCount {
                            leftChannel[frame] = 0
                            rightChannel[frame] = 0
                            frame += 1
                        }
                        break
                    }
                }
                oplSamplesUntilNextTick += max(oplSamplesPerTick, 1)
            }

            // Generate samples up to the next tick boundary using batch method
            let samplesToTick = Int(ceil(oplSamplesUntilNextTick))
            let samplesToGenerate = min(samplesToTick, oplBufferFrameCount - frame)

            opl3fm.generateFrames(count: samplesToGenerate,
                                  leftChannel: leftChannel,
                                  rightChannel: rightChannel,
                                  offset: frame,
                                  scale: scale)
            frame += samplesToGenerate
            oplSamplesUntilNextTick -= Double(samplesToGenerate)
        }

        // A stop from the tick callback already tore playback down. Drop this buffer.
        guard !oplStopped else { return false }

#if os(iOS)
        // .dataConsumed fires once the node has finished reading the buffer, which is
        // early enough to synthesize the replacement while the rest of the lead still plays.
        let generation = oplGeneration
        oplScheduledBufferCount += 1
        oplNode.scheduleBuffer(buffer, completionCallbackType: .dataConsumed) { [weak self] _ in
            self?.oplQueue.async {
                guard let self else { return }
                self.releaseOPL3Buffer(buffer)
                guard self.oplGeneration == generation, !self.oplStopped else { return }
                self.oplScheduledBufferCount -= 1
                self.produceOPL3Buffer()
            }
        }
#else
        // Schedule buffer and return to pool when playback completes
        oplNode.scheduleBuffer(buffer) { [weak self] in
            self?.oplQueue.async {
                self?.releaseOPL3Buffer(buffer)
            }
        }
#endif
        return true
    }
  
  
    func node(for type: AudioPlayerItemType) -> AVAudioPlayerNode {
      switch type {
        case .music:
          return oplNode
        
        case .sound:
          return soundFxNode
      }
    }
    
    /// Mutes the OPL3 output
    func muteOPL3() {
        oplMixerNode.outputVolume = 0.0
    }
    
    /// Unmutes the OPL3 output
    func unmuteOPL3() {
        oplMixerNode.outputVolume = 1.0
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
  
  
    func stop() {
      if let currentAudioItem = currentAudioItem {
        currentAudioItem.stop()
      }
      
      self.currentAudioItem = nil

      if let currentMusicItem = currentMusicItem {
        currentMusicItem.stop()
      }
      
      self.currentMusicItem = nil
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
