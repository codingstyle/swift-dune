//
//  OPL3Fm.swift
//  SwiftDune
//
//  Ported from Spice86 OPL3Fm implementation
//  Original: https://github.com/OpenRakis/Spice86/blob/master/src/Spice86.Core/Emulator/Devices/Sound/Opl3Fm.cs
//
//  Created by Christophe Buguet on 04/02/2026.
//

import Foundation
import AVFoundation

/// OPL3 FM Synthesizer - High-level wrapper around OPL3Chip
/// Provides audio generation and playback management for FM synthesis
public final class OPL3Fm {
    // MARK: - Constants

    /// Maximum samples per generation batch (prevents buffer overruns)
    private static let maxSamplesPerGenerationBatch = 512

    /// Standard OPL3 sample rate
    public static let oplSampleRate: UInt32 = 49716

    // MARK: - OPL3 Chip

    /// The underlying OPL3 chip emulator
    public let chip: OPL3Chip

    /// Current sample rate
    public private(set) var sampleRate: UInt32

    /// Hardware type (AdLib, AdLib Gold, Sound Blaster)
    public var hardwareType: OPL3HardwareType = .adlib

    /// Whether AdLib Gold features are enabled
    public var isAdlibGold: Bool {
        return hardwareType == .adlibGold
    }

    // MARK: - Sample Buffers

    /// Temporary interleaved sample buffer for generation
    private var tempInterleaved: [Int16] = Array(repeating: 0, count: 2048)

    /// Frame sample buffer (2 samples for stereo)
    public var frameSampleBuffer: [Int16] = [0, 0]

    /// Main sample buffer for accumulating samples
    public var sampleBuffer: [Int16]

    /// Current write index into sample buffer
    public var sampleBufferIndex: Int = 0

    /// Lock for thread-safe chip access
    private let chipLock = NSLock()

    // MARK: - Initialization

    /// Initializes a new OPL3 FM synthesizer
    /// - Parameters:
    ///   - sampleRate: Output sample rate (default: 49716 Hz)
    ///   - bufferSize: Size of the sample buffer (default: 8192)
    ///   - hardwareType: Type of hardware to emulate
    public init(sampleRate: UInt32 = oplSampleRate, bufferSize: Int = 8192, hardwareType: OPL3HardwareType = .adlib) {
        self.chip = OPL3Chip()
        self.sampleRate = sampleRate
        self.hardwareType = hardwareType
        self.sampleBuffer = Array(repeating: 0, count: bufferSize)

        // Reset and initialize the chip
        reset(sampleRate)
    }

    // MARK: - Chip Control

    /// Resets the OPL3 chip
    /// - Parameter sampleRate: Sample rate to use
    public func reset(_ sampleRate: UInt32) {
        chipLock.lock()
        defer { chipLock.unlock() }

        self.sampleRate = sampleRate
        chip.reset(sampleRate)

        // Initialize tone generators with default values
        initializeToneGenerators()
    }

    /// Initializes default envelopes and rates for the OPL3 operators
    private func initializeToneGenerators() {
        // 4-op channels (first slots)
        let fourOpIndices: [Int] = [0, 1, 2, 6, 7, 8, 12, 13, 14]
        var idx = 0
        while idx < fourOpIndices.count {
            let slot = chip.slots[fourOpIndices[idx]]
            slot.envelopeGeneratorOutput = 0x1FF
            slot.envelopeGeneratorLevel = 571
            // Must be .release so note-on can trigger attack phase
            slot.envelopeGeneratorState = OPL3EnvelopeGeneratorStage.release.rawValue
            slot.regFrequencyMultiplier = 1
            slot.regKeyScaleLevel = 1
            slot.regTotalLevel = 15
            slot.regAttackRate = 15
            slot.regDecayRate = 1
            slot.regSustainLevel = 5
            slot.regReleaseRate = 3
            idx += 1
        }

        // 2-op channels (second slots)
        let twoOpIndices: [Int] = [3, 4, 5, 9, 10, 11, 15, 16, 17]
        idx = 0
        while idx < twoOpIndices.count {
            let slot = chip.slots[twoOpIndices[idx]]
            slot.envelopeGeneratorOutput = 0x1FF
            slot.envelopeGeneratorLevel = 0x1FF
            // Must be .release so note-on can trigger attack phase
            slot.envelopeGeneratorState = OPL3EnvelopeGeneratorStage.release.rawValue
            slot.regKeyScaleRate = 1
            slot.regFrequencyMultiplier = 1
            slot.regAttackRate = 15
            slot.regDecayRate = 2
            slot.regSustainLevel = 7
            slot.regReleaseRate = 4
            idx += 1
        }
    }

    // MARK: - Register Access

    /// Writes a value directly to an OPL3 register (thread-safe)
    /// - Parameters:
    ///   - register: Register address (0x000-0x1FF)
    ///   - value: Value to write
    public func writeRegister(_ register: UInt16, _ value: UInt8) {
        chipLock.lock()
        defer { chipLock.unlock() }

      chip.writeRegister(register, value)
    }

    /// Lock-free register write for use on the audio generation queue only.
    /// Both event processing and audio generation run on the same serial queue,
    /// so no lock is needed. Avoids lock overhead on the hot path.
    @inline(__always)
    public func writeRegisterDirect(_ register: UInt16, _ value: UInt8) {
        chip.writeRegister(register, value)
    }

    /// Writes a value to an OPL3 register with buffering for timing accuracy
    /// - Parameters:
    ///   - register: Register address (0x000-0x1FF)
    ///   - value: Value to write
    public func writeRegisterBuffered(_ register: UInt16, _ value: UInt8) {
        chipLock.lock()
        defer { chipLock.unlock() }

        chip.writeRegisterBuffered(register, value)
    }

    private var debugWriteCount: Int = 0

    // MARK: - Audio Generation

    /// Generates a single stereo sample frame
    /// Updates frameSampleBuffer with the generated samples
    /// NOTE: Lock-free for real-time audio thread safety
    @inline(__always)
    public func generateFrame() {
        frameSampleBuffer[0] = 0
        frameSampleBuffer[1] = 0

        chip.generateResampled(&frameSampleBuffer)
    }

    /// Generates multiple stereo frames directly to left/right float channel buffers.
    /// More efficient than calling generateFrame() in a loop: keeps everything in a
    /// tight loop with minimal per-sample overhead.
    /// - Parameters:
    ///   - count: Number of stereo frames to generate
    ///   - leftChannel: Pointer to left channel float buffer
    ///   - rightChannel: Pointer to right channel float buffer
    ///   - offset: Starting offset in the output buffers
    ///   - scale: Scaling factor for Int16 → Float conversion
    @inline(__always)
    public func generateFrames(count: Int,
                               leftChannel: UnsafeMutablePointer<Float>,
                               rightChannel: UnsafeMutablePointer<Float>,
                               offset: Int,
                               scale: Float) {
        var idx = 0
        while idx < count {
            frameSampleBuffer[0] = 0
            frameSampleBuffer[1] = 0
            chip.generateResampled(&frameSampleBuffer)
            leftChannel[offset + idx] = Float(frameSampleBuffer[0]) * scale
            rightChannel[offset + idx] = Float(frameSampleBuffer[1]) * scale
            idx += 1
        }
    }

    // Debug counter for non-zero frames
    private var debugNonZeroFrameCount: Int = 0

    /// Generates audio and accumulates into the sample buffer
    /// Call this method at the OPL3 sample rate (49716 Hz)
    /// Returns true when the buffer is full and ready for playback
    @discardableResult
    public func update() -> Bool {
        generateFrame()

        sampleBuffer[sampleBufferIndex] = frameSampleBuffer[0]
        sampleBufferIndex += 1
        sampleBuffer[sampleBufferIndex] = frameSampleBuffer[1]
        sampleBufferIndex += 1

        if sampleBufferIndex >= sampleBuffer.count {
            sampleBufferIndex = 0
            return true
        }

        return false
    }

    /// Generates a stream of audio samples
    /// - Parameter buffer: Destination buffer for interleaved stereo samples
    public func generateStream(_ buffer: inout [Int16]) {
        chipLock.lock()
        defer { chipLock.unlock() }

        chip.generateStream(&buffer)
    }

    /// Generates resampled audio samples
    /// - Parameter buffer: Destination buffer for interleaved stereo samples
    public func generateResampled(_ buffer: inout [Int16]) {
        chipLock.lock()
        defer { chipLock.unlock() }

        chip.generateResampled(&buffer)
    }

    /// Renders audio samples into a float buffer
    /// - Parameter destination: Interleaved stereo float buffer
    public func render(to destination: inout [Float]) {
        let frames = destination.count / 2
        guard frames > 0 else {
            destination = Array(repeating: 0, count: destination.count)
            return
        }

        let samples = frames * 2
        if samples > tempInterleaved.count {
            tempInterleaved = Array(repeating: 0, count: samples)
        }

        var generatedSamples = 0
        while generatedSamples < samples {
            let batchSamples = min(Self.maxSamplesPerGenerationBatch, samples - generatedSamples)
            var batch = Array(tempInterleaved[generatedSamples..<(generatedSamples + batchSamples)])

            chipLock.lock()
            chip.generateStream(&batch)
            chipLock.unlock()

            var batchIdx = 0
            while batchIdx < batchSamples {
                tempInterleaved[generatedSamples + batchIdx] = batch[batchIdx]
                batchIdx += 1
            }

            generatedSamples += batchSamples
        }

        // Convert Int16 to Float (-1.0 to 1.0)
        let scale: Float = 1.0 / 32768.0
        var sIdx = 0
        while sIdx < samples {
            destination[sIdx] = Float(tempInterleaved[sIdx]) * scale
            sIdx += 1
        }
    }

    /// Clears the sample buffer
    public func clearSampleBuffer() {
        var idx = 0
        while idx < sampleBuffer.count {
            sampleBuffer[idx] = 0
            idx += 1
        }
        sampleBufferIndex = 0
    }
    
    /// Silences all OPL3 channels by turning off all keys
    public func silence() {
        chipLock.lock()
        defer { chipLock.unlock() }

        // Turn off all keys on channels 0-8 (first register bank)
        var ch = 0
        while ch < 9 {
            chip.writeRegister(UInt16(0xB0 + ch), 0x00)
            ch += 1
        }

        // Turn off all keys on channels 9-17 (second register bank, 0x100 offset)
        ch = 0
        while ch < 9 {
            chip.writeRegister(UInt16(0x1B0 + ch), 0x00)
            ch += 1
        }

        clearSampleBuffer()
    }

    // MARK: - AVAudioPCMBuffer Generation

    /// Creates an AVAudioPCMBuffer from the current sample buffer
    /// - Parameter format: Audio format for the buffer
    /// - Returns: PCM buffer ready for playback, or nil on failure
    public func createPCMBuffer(format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let frameCount = AVAudioFrameCount(sampleBuffer.count / 2)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return nil
        }

        buffer.frameLength = frameCount

        guard let floatChannelData = buffer.floatChannelData else {
            return nil
        }

        let leftChannel = floatChannelData[0]
        let rightChannel = format.channelCount > 1 ? floatChannelData[1] : floatChannelData[0]

        var frameIndex = 0
        var sampleIndex = 0

        while frameIndex < frameCount {
            leftChannel[frameIndex] = Float(sampleBuffer[sampleIndex]) / Float(Int16.max)
            rightChannel[frameIndex] = Float(sampleBuffer[sampleIndex + 1]) / Float(Int16.max)

            sampleIndex += 2
            frameIndex += 1
        }

        return buffer
    }
}

// MARK: - Hardware Type

/// OPL3 hardware type enumeration
public enum OPL3HardwareType {
    case adlib
    case adlibGold
    case soundBlaster
}

// MARK: - OPL3 Port Constants

/// OPL3 I/O port numbers (for reference/compatibility)
public struct OPL3Port {
    public static let primaryAddressPort: UInt16 = 0x388
    public static let primaryDataPort: UInt16 = 0x389
    public static let secondaryAddressPort: UInt16 = 0x38A
    public static let secondaryDataPort: UInt16 = 0x38B
    public static let adlibGoldAddressPort: UInt16 = 0x38C
    public static let adlibGoldDataPort: UInt16 = 0x38D
}
