//
//  OPL3Chip.swift
//  SwiftDune
//
//  Ported from Nuked OPL3 (Spice86 C# implementation)
//  Original C code: Copyright (C) 2013-2020 Nuke.YKT
//  SPDX-License-Identifier: LGPL-2.1
//
//  Created by Christophe Buguet on 04/02/2026.
//

import Foundation

/// Write buffer entry for buffered register writes
struct OPL3WriteBufferEntry {
    var data: UInt8 = 0
    var register: UInt16 = 0
    var time: UInt64 = 0
}

/// OPL3 Chip - Main FM synthesis chip emulator
public final class OPL3Chip {
    // MARK: - Constants
    
    private static let writeBufferSize = 1024
    private static let writeBufferDelay = 2
    private static let resampleFractionBits = 10
    
    // MARK: - Channels and Slots
    
    private(set) var channels: [OPL3Channel] = []
    public private(set) var slots: [OPL3Operator] = []
    
    // MARK: - Chip State
    
    var timer: UInt16 = 0
    var egTimer: UInt64 = 0
    var egTimerRem: UInt8 = 0
    var egState: UInt8 = 0
    var egAdd: UInt8 = 0
    var egTimerLow: UInt8 = 0
    var newM: UInt8 = 0
    var nts: UInt8 = 0
    var rhythm: UInt8 = 0
    var vibratoPosition: UInt8 = 0
    var vibratoShift: UInt8 = 0
    var tremolo: UInt8 = 0
    var tremoloPosition: UInt8 = 0
    var tremoloShift: UInt8 = 0
    var noise: UInt32 = 1
    var zeroMod: Int16 = 0
    
    /// 4-channel mix accumulator (used only by generate4ChCore)
    private var mixBuf0: Int32 = 0
    private var mixBuf1: Int32 = 0
    private var mixBuf2: Int32 = 0
    private var mixBuf3: Int32 = 0

    var rhythmHihatBit2: UInt8 = 0
    var rhythmHihatBit3: UInt8 = 0
    var rhythmHihatBit7: UInt8 = 0
    var rhythmHihatBit8: UInt8 = 0
    var rhythmTomBit3: UInt8 = 0
    var rhythmTomBit5: UInt8 = 0
    
    var rateRatio: Int32 = 0
    /// log2(rateRatio) when rateRatio is an exact power of 2 (e.g. 10 for 49716 Hz → ratio 1024),
    /// or -1 when it is not. Used to replace the two integer divisions per output sample with
    /// a single arithmetic right-shift, which is significantly cheaper in debug builds.
    var rateRatioShift: Int32 = -1
    var sampleCounter: Int32 = 0
    
    /// Stereo resampler state — previous and current computed OPL3 sample (no heap, no ARC)
    private var sampleL: Int16 = 0
    private var sampleR: Int16 = 0
    private var oldSampleL: Int16 = 0
    private var oldSampleR: Int16 = 0

    /// 4-channel resampler state (heap arrays; only used by the non-audio-playback 4ch path)
    private var samples4ch: [Int16] = [0, 0, 0, 0]
    private var oldSamples4ch: [Int16] = [0, 0, 0, 0]
    
    var writeBufferSampleCounter: UInt64 = 0
    var writeBufferCurrent: UInt32 = 0
    var writeBufferLast: UInt32 = 0
    var writeBufferLastTime: UInt64 = 0
    
    private var writeBuffer: [OPL3WriteBufferEntry] = []
    private var debugWriteProcessCount: Int = 0
    
    // MARK: - Initialization
    
    public init() {
        // Initialize channels
        channels = (0..<18).map { i in
            let channel = OPL3Channel()
            channel.chip = self
            channel.channelNumber = UInt8(i)
            channel.channelType = .twoOp
            return channel
        }
        
        // Initialize slots
        slots = (0..<36).map { i in
            let slot = OPL3Operator()
            slot.chip = self
            slot.slotIndex = UInt8(i)
            slot.modulationSource = .zero
            slot.tremoloEnabled = false
            return slot
        }
        
        // Initialize write buffer
        writeBuffer = (0..<Self.writeBufferSize).map { _ in OPL3WriteBufferEntry() }
    }
    
    // MARK: - Public API
    
    /// Resets the chip to initial state
    public func reset(_ sampleRate: UInt32) {
        resetInternal(sampleRate)
    }
    
    /// Writes a value to a register
    public func writeRegister(_ register: UInt16, _ value: UInt8) {
        writeRegisterInternal(register, value)
    }
    
    /// Writes a value to a register with buffering
    public func writeRegisterBuffered(_ register: UInt16, _ value: UInt8) {
        writeRegisterBufferedInternal(register, value)
    }
    
    /// Generates 4 channels of audio
    public func generate4Channels(_ buffer: inout [Int16]) {
        generate4ChCore(&buffer)
    }
    
    /// Generates stereo audio
    public func generate(_ buffer: inout [Int16]) {
        generateCore(&buffer)
    }
    
    /// Generates 4 channels with resampling
    public func generate4ChannelsResampled(_ buffer: inout [Int16]) {
        generate4ChResampledCore(&buffer)
    }
    
    /// Generates stereo audio with resampling
    @inline(__always)
    public func generateResampled(_ buffer: inout [Int16]) {
        generateResampledCore(&buffer)
    }
    
    /// Generates a stream of 4-channel audio
    public func generate4ChannelStream(_ stream1: inout [Int16], _ stream2: inout [Int16]) {
        generate4ChStreamCore(&stream1, &stream2)
    }
    
    /// Generates a stream of stereo audio
    public func generateStream(_ stream: inout [Int16]) {
        generateStreamCore(&stream)
    }
    
    // MARK: - Phase Generator
    
    @inline(__always)
    private func phaseGenerate(_ slot: OPL3Operator) {
        let channel = slot.channel!
        
        var fNum = Int(channel.fNumber)
        
        if slot.regVibrato != 0 {
            var range = (fNum >> 7) & 0x07
            let vibPos = vibratoPosition
            
            if (vibPos & 0x03) == 0 {
                range = 0
            } else if (vibPos & 0x01) != 0 {
                range >>= 1
            }
            
            range >>= Int(vibratoShift)
            
            if (vibPos & 0x04) != 0 {
                range = -range
            }
            
            fNum = fNum &+ range
        }
        
        let baseFreq = UInt32((fNum << Int(channel.block)) >> 1)
        let phase = UInt16(truncatingIfNeeded: slot.regPhaseGeneratorAccumulator >> 9)
        
        if slot.regPhaseResetRequest != 0 {
            slot.regPhaseGeneratorAccumulator = 0
        }
        
        let freqMultiplier = OPL3Tables.readFrequencyMultiplier(Int(slot.regFrequencyMultiplier))
        slot.regPhaseGeneratorAccumulator = slot.regPhaseGeneratorAccumulator &+ ((baseFreq &* UInt32(freqMultiplier)) >> 1)
        
        let currentNoise = noise
        slot.phaseGeneratorOutput = phase
        
        // Handle hi-hat phase bits
        switch slot.slotIndex {
        case 13: // hh
            rhythmHihatBit2 = UInt8((phase >> 2) & 1)
            rhythmHihatBit3 = UInt8((phase >> 3) & 1)
            rhythmHihatBit7 = UInt8((phase >> 7) & 1)
            rhythmHihatBit8 = UInt8((phase >> 8) & 1)
        case 17 where (rhythm & 0x20) != 0: // tc
            rhythmTomBit3 = UInt8((phase >> 3) & 1)
            rhythmTomBit5 = UInt8((phase >> 5) & 1)
        default:
            break
        }
        
        // Rhythm mode processing
        if (rhythm & 0x20) != 0 {
            let rmXor = UInt8(((rhythmHihatBit2 ^ rhythmHihatBit7)
                | (rhythmHihatBit3 ^ rhythmTomBit5)
                | (rhythmTomBit3 ^ rhythmTomBit5)) & 0x01)
            
            switch slot.slotIndex {
            case 13: // hh
                slot.phaseGeneratorOutput = UInt16(rmXor) << 9
                if ((rmXor ^ UInt8(currentNoise & 0x01)) & 0x01) != 0 {
                    slot.phaseGeneratorOutput |= 0xD0
                } else {
                    slot.phaseGeneratorOutput |= 0x34
                }
            case 16: // sd
                let noiseBit = UInt8(currentNoise & 0x01)
                slot.phaseGeneratorOutput = UInt16(((rhythmHihatBit8 & 0x01) << 9)
                    | (((rhythmHihatBit8 ^ noiseBit) & 0x01) << 8))
            case 17: // tc
                slot.phaseGeneratorOutput = UInt16(rmXor << 9) | 0x80
            default:
                break
            }
        }
        
        // Update noise
        let nBit = ((currentNoise >> 14) ^ currentNoise) & 0x01
        noise = (currentNoise >> 1) | (nBit << 22)
    }
    
    // MARK: - Slot Register Writes
    
    private func slotWrite20(_ slot: OPL3Operator, _ data: UInt8) {
        slot.tremoloEnabled = ((data >> 7) & 0x01) != 0
        slot.regVibrato = (data >> 6) & 0x01
        slot.regOperatorType = (data >> 5) & 0x01
        slot.regKeyScaleRate = (data >> 4) & 0x01
        slot.regFrequencyMultiplier = data & 0x0F
    }
    
    private func slotWrite40(_ slot: OPL3Operator, _ data: UInt8) {
        slot.regKeyScaleLevel = (data >> 6) & 0x03
        slot.regTotalLevel = data & 0x3F
        OPL3Envelope.envelopeUpdateKsl(slot)
    }
    
    private func slotWrite60(_ slot: OPL3Operator, _ data: UInt8) {
        slot.regAttackRate = (data >> 4) & 0x0F
        slot.regDecayRate = data & 0x0F
    }
    
    private func slotWrite80(_ slot: OPL3Operator, _ data: UInt8) {
        slot.regSustainLevel = (data >> 4) & 0x0F
        if slot.regSustainLevel == 0x0F {
            slot.regSustainLevel = 0x1F
        }
        slot.regReleaseRate = data & 0x0F
    }
    
    private func slotWriteE0(_ slot: OPL3Operator, _ data: UInt8) {
        slot.regWaveformSelect = data & 0x07
        if newM == 0 {
            slot.regWaveformSelect &= 0x03
        }
    }
    
    // MARK: - Slot Processing
    
    @inline(__always)
    private func slotGenerate(_ slot: OPL3Operator) {
        slot.out = OPL3Envelope.generateWaveform(slot)
    }
    
    @inline(__always)
    private func slotCalcFeedback(_ slot: OPL3Operator) {
        let channel = slot.channel!
        
        if channel.feedback != 0 {
            slot.feedbackModifiedSignal = (slot.previousOutputSample &+ slot.out) >> (0x09 - Int(channel.feedback))
        } else {
            slot.feedbackModifiedSignal = 0
        }
        
      slot.previousOutputSample = slot.out
    }
    
    @inline(__always)
    private func processSlot(_ slot: OPL3Operator) {
        // NukedOPL3 order: CalcFB first (uses PREVIOUS output for feedback),
        // then envelope, phase, and generate (produces NEW output)
        slotCalcFeedback(slot)
        OPL3Envelope.envelopeCalc(slot)
        phaseGenerate(slot)
        slotGenerate(slot)
    }
    
    // MARK: - Channel Setup
    
    private func channelSetupAlgorithm(_ channel: OPL3Channel) {
        if channel.channelType == .drum {
            if channel.channelNumber == 7 || channel.channelNumber == 8 {
                channel.slotz[0].modulationSource = .zero
                channel.slotz[1].modulationSource = .zero
                return
            }
            
            switch channel.algorithm & 0x01 {
            case 0x00:
                channel.slotz[0].modulationSource = channel.slotz[0].feedbackSignal
                channel.slotz[1].modulationSource = channel.slotz[0].outputSignal
            case 0x01:
                channel.slotz[0].modulationSource = channel.slotz[0].feedbackSignal
                channel.slotz[1].modulationSource = .zero
            default:
                break
            }
            return
        }
        
        if (channel.algorithm & 0x08) != 0 {
            return
        }
        
        if (channel.algorithm & 0x04) != 0 {
            guard let pair = channel.pair else { return }
            
            pair.outSlot0 = -1
            pair.outSlot1 = -1
            pair.outSlot2 = -1
            pair.outSlot3 = -1
            
            switch channel.algorithm & 0x03 {
            case 0x00:
                pair.slotz[0].modulationSource = pair.slotz[0].feedbackSignal
                pair.slotz[1].modulationSource = pair.slotz[0].outputSignal
                channel.slotz[0].modulationSource = pair.slotz[1].outputSignal
                channel.slotz[1].modulationSource = channel.slotz[0].outputSignal
                channel.outSlot0 = Int8(channel.slotz[1].slotIndex)
                channel.outSlot1 = -1
                channel.outSlot2 = -1
                channel.outSlot3 = -1
            case 0x01:
                pair.slotz[0].modulationSource = pair.slotz[0].feedbackSignal
                pair.slotz[1].modulationSource = pair.slotz[0].outputSignal
                channel.slotz[0].modulationSource = .zero
                channel.slotz[1].modulationSource = channel.slotz[0].outputSignal
                channel.outSlot0 = Int8(pair.slotz[1].slotIndex)
                channel.outSlot1 = Int8(channel.slotz[1].slotIndex)
                channel.outSlot2 = -1
                channel.outSlot3 = -1
            case 0x02:
                pair.slotz[0].modulationSource = pair.slotz[0].feedbackSignal
                pair.slotz[1].modulationSource = .zero
                channel.slotz[0].modulationSource = pair.slotz[1].outputSignal
                channel.slotz[1].modulationSource = channel.slotz[0].outputSignal
                channel.outSlot0 = Int8(pair.slotz[0].slotIndex)
                channel.outSlot1 = Int8(channel.slotz[1].slotIndex)
                channel.outSlot2 = -1
                channel.outSlot3 = -1
            case 0x03:
                pair.slotz[0].modulationSource = pair.slotz[0].feedbackSignal
                pair.slotz[1].modulationSource = .zero
                channel.slotz[0].modulationSource = pair.slotz[1].outputSignal
                channel.slotz[1].modulationSource = .zero
                channel.outSlot0 = Int8(pair.slotz[0].slotIndex)
                channel.outSlot1 = Int8(channel.slotz[0].slotIndex)
                channel.outSlot2 = Int8(channel.slotz[1].slotIndex)
                channel.outSlot3 = -1
            default:
                break
            }
        } else {
            switch channel.algorithm & 0x01 {
            case 0x00:
                channel.slotz[0].modulationSource = channel.slotz[0].feedbackSignal
                channel.slotz[1].modulationSource = channel.slotz[0].outputSignal
                channel.outSlot0 = Int8(channel.slotz[1].slotIndex)
                channel.outSlot1 = -1
                channel.outSlot2 = -1
                channel.outSlot3 = -1
            case 0x01:
                channel.slotz[0].modulationSource = channel.slotz[0].feedbackSignal
                channel.slotz[1].modulationSource = .zero
                channel.outSlot0 = Int8(channel.slotz[0].slotIndex)
                channel.outSlot1 = Int8(channel.slotz[1].slotIndex)
                channel.outSlot2 = -1
                channel.outSlot3 = -1
            default:
                break
            }
        }
    }
    
    // MARK: - Channel Rhythm Update
    
    private func channelUpdateRhythm(_ data: UInt8) {
        rhythm = data & 0x3F
        
        if (rhythm & 0x20) != 0 {
            let channel6 = channels[6]
            let channel7 = channels[7]
            let channel8 = channels[8]
            
            channel6.outSlot0 = Int8(channel6.slotz[1].slotIndex)
            channel6.outSlot1 = Int8(channel6.slotz[1].slotIndex)
            channel6.outSlot2 = -1
            channel6.outSlot3 = -1
            
            channel7.outSlot0 = Int8(channel7.slotz[0].slotIndex)
            channel7.outSlot1 = Int8(channel7.slotz[0].slotIndex)
            channel7.outSlot2 = Int8(channel7.slotz[1].slotIndex)
            channel7.outSlot3 = Int8(channel7.slotz[1].slotIndex)
            
            channel8.outSlot0 = Int8(channel8.slotz[0].slotIndex)
            channel8.outSlot1 = Int8(channel8.slotz[0].slotIndex)
            channel8.outSlot2 = Int8(channel8.slotz[1].slotIndex)
            channel8.outSlot3 = Int8(channel8.slotz[1].slotIndex)
            
            var ch = 6
            while ch < 9 {
                channels[ch].channelType = .drum
                ch += 1
            }
            
            channelSetupAlgorithm(channel6)
            channelSetupAlgorithm(channel7)
            channelSetupAlgorithm(channel8)
            
            // hh
            if (rhythm & 0x01) != 0 {
                OPL3Envelope.envelopeKeyOn(channel7.slotz[0], .drum)
            } else {
                OPL3Envelope.envelopeKeyOff(channel7.slotz[0], .drum)
            }
            
            // tc
            if (rhythm & 0x02) != 0 {
                OPL3Envelope.envelopeKeyOn(channel8.slotz[1], .drum)
            } else {
                OPL3Envelope.envelopeKeyOff(channel8.slotz[1], .drum)
            }
            
            // tom
            if (rhythm & 0x04) != 0 {
                OPL3Envelope.envelopeKeyOn(channel8.slotz[0], .drum)
            } else {
                OPL3Envelope.envelopeKeyOff(channel8.slotz[0], .drum)
            }
            
            // sd
            if (rhythm & 0x08) != 0 {
                OPL3Envelope.envelopeKeyOn(channel7.slotz[1], .drum)
            } else {
                OPL3Envelope.envelopeKeyOff(channel7.slotz[1], .drum)
            }
            
            // bd
            if (rhythm & 0x10) != 0 {
                OPL3Envelope.envelopeKeyOn(channel6.slotz[0], .drum)
                OPL3Envelope.envelopeKeyOn(channel6.slotz[1], .drum)
            } else {
                OPL3Envelope.envelopeKeyOff(channel6.slotz[0], .drum)
                OPL3Envelope.envelopeKeyOff(channel6.slotz[1], .drum)
            }
        } else {
            var ch = 6
            while ch < 9 {
                let channel = channels[ch]
                channel.channelType = .twoOp
                channel.outSlot0 = -1
                channel.outSlot1 = -1
                channel.outSlot2 = -1
                channel.outSlot3 = -1
                channelSetupAlgorithm(channel)
                ch += 1
            }
        }
    }
    
    // MARK: - Channel Register Writes
    
    private func channelWriteA0(_ channel: OPL3Channel, _ data: UInt8) {
        if newM != 0 && channel.channelType == .fourOpPair {
            return
        }

        channel.fNumber = (channel.fNumber & 0x300) | UInt16(data)
        channel.keyScaleValue = (channel.block << 1) | UInt8((channel.fNumber >> (0x09 - Int(nts))) & 0x01)
        OPL3Envelope.envelopeUpdateKsl(channel.slotz[0])
        OPL3Envelope.envelopeUpdateKsl(channel.slotz[1])

        if newM == 0 || channel.channelType != .fourOp {
            return
        }

        guard let pair = channel.pair else { return }
        pair.fNumber = channel.fNumber
        pair.keyScaleValue = channel.keyScaleValue
        OPL3Envelope.envelopeUpdateKsl(pair.slotz[0])
        OPL3Envelope.envelopeUpdateKsl(pair.slotz[1])
    }
    
    private func channelWriteB0(_ channel: OPL3Channel, _ data: UInt8) {
        // Convert to UInt16 BEFORE shifting, otherwise shifting UInt8 by 8 bits = 0
        channel.fNumber = (channel.fNumber & 0xFF) | (UInt16(data & 0x03) << 8)
        channel.block = (data >> 2) & 0x07
        channel.keyScaleValue = (channel.block << 1) | UInt8((channel.fNumber >> (0x09 - Int(nts))) & 0x01)
        
        OPL3Envelope.envelopeUpdateKsl(channel.slotz[0])
        OPL3Envelope.envelopeUpdateKsl(channel.slotz[1])
        
        if newM == 0 || channel.channelType != .fourOp {
            return
        }
        
        guard let pair = channel.pair else { return }
        pair.fNumber = channel.fNumber
        pair.block = channel.block
        pair.keyScaleValue = channel.keyScaleValue
        OPL3Envelope.envelopeUpdateKsl(pair.slotz[0])
        OPL3Envelope.envelopeUpdateKsl(pair.slotz[1])
    }
    
    private func channelUpdateAlgorithm(_ channel: OPL3Channel) {
        channel.algorithm = channel.connection
        
        if newM != 0 {
            switch channel.channelType {
            case .fourOp:
                guard let pair = channel.pair else { return }
                pair.algorithm = 0x04 | (channel.connection << 1) | pair.connection
                channel.algorithm = 0x08
                channelSetupAlgorithm(pair)
            case .fourOpPair:
                guard let primary = channel.pair else { return }
                channel.algorithm = 0x04 | (primary.connection << 1) | channel.connection
                primary.algorithm = 0x08
                channelSetupAlgorithm(channel)
            default:
                channelSetupAlgorithm(channel)
            }
        } else {
            channelSetupAlgorithm(channel)
        }
    }
    
    private func channelWriteC0(_ channel: OPL3Channel, _ data: UInt8) {
        channel.feedback = (data & 0x0E) >> 1
        channel.connection = data & 0x01
        channelUpdateAlgorithm(channel)
        
        if newM != 0 {
            channel.cha = ((data >> 4) & 0x01) != 0 ? 0xFFFF : 0
            channel.chb = ((data >> 5) & 0x01) != 0 ? 0xFFFF : 0
            // chc and chd are always 0 in the original NukedOPL3
            channel.chc = 0
            channel.chd = 0
        } else {
            channel.cha = 0xFFFF
            channel.chb = 0xFFFF
            channel.chc = 0
            channel.chd = 0
        }
    }
    
    // MARK: - Channel Key On/Off
    
    private func channelKeyOn(_ channel: OPL3Channel) {
        if newM != 0 {
            switch channel.channelType {
            case .fourOp:
                guard let pair = channel.pair else { return }
                OPL3Envelope.envelopeKeyOn(channel.slotz[0], .normal)
                OPL3Envelope.envelopeKeyOn(channel.slotz[1], .normal)
                OPL3Envelope.envelopeKeyOn(pair.slotz[0], .normal)
                OPL3Envelope.envelopeKeyOn(pair.slotz[1], .normal)
            case .twoOp, .drum:
                OPL3Envelope.envelopeKeyOn(channel.slotz[0], .normal)
                OPL3Envelope.envelopeKeyOn(channel.slotz[1], .normal)
            default:
                break
            }
        } else {
            OPL3Envelope.envelopeKeyOn(channel.slotz[0], .normal)
            OPL3Envelope.envelopeKeyOn(channel.slotz[1], .normal)
        }
    }
    
    private func channelKeyOff(_ channel: OPL3Channel) {
        if newM != 0 {
            switch channel.channelType {
            case .fourOp:
                guard let pair = channel.pair else { return }
                OPL3Envelope.envelopeKeyOff(channel.slotz[0], .normal)
                OPL3Envelope.envelopeKeyOff(channel.slotz[1], .normal)
                OPL3Envelope.envelopeKeyOff(pair.slotz[0], .normal)
                OPL3Envelope.envelopeKeyOff(pair.slotz[1], .normal)
            case .twoOp, .drum:
                OPL3Envelope.envelopeKeyOff(channel.slotz[0], .normal)
                OPL3Envelope.envelopeKeyOff(channel.slotz[1], .normal)
            default:
                break
            }
        } else {
            OPL3Envelope.envelopeKeyOff(channel.slotz[0], .normal)
            OPL3Envelope.envelopeKeyOff(channel.slotz[1], .normal)
        }
    }
    
    // MARK: - 4-Op Mode Setup
    
    private func channelSet4Op(_ data: UInt8) {
        var bit = 0
        while bit < 6 {
            var chNum = bit
            if bit >= 3 {
                chNum = bit + 6
            }
            
            if ((data >> bit) & 0x01) != 0 {
                channels[chNum].channelType = .fourOp
                channels[chNum + 3].channelType = .fourOpPair
                channelUpdateAlgorithm(channels[chNum])
            } else {
                channels[chNum].channelType = .twoOp
                channels[chNum + 3].channelType = .twoOp
                channelUpdateAlgorithm(channels[chNum])
                channelUpdateAlgorithm(channels[chNum + 3])
            }
            bit += 1
        }
    }
    
    // MARK: - Sample Clipping
    
    @inline(__always)
    private func clipSample(_ sample: Int32) -> Int16 {
        if sample > Int32(Int16.max) {
            return Int16.max
        } else if sample < Int32(Int16.min) {
            return Int16.min
        }
        return Int16(truncatingIfNeeded: sample)
    }
    
    // MARK: - Channel Output Summing
    
    @inline(__always)
    private func sumChannelOutputs(_ channel: OPL3Channel) -> Int {
        var sum = 0
      
        if channel.outSlot0 >= 0 { sum &+= Int(slots[Int(channel.outSlot0)].out) }
        if channel.outSlot1 >= 0 { sum &+= Int(slots[Int(channel.outSlot1)].out) }
        if channel.outSlot2 >= 0 { sum &+= Int(slots[Int(channel.outSlot2)].out) }
        if channel.outSlot3 >= 0 { sum &+= Int(slots[Int(channel.outSlot3)].out) }
      
        return sum
    }
    
    // MARK: - Generation Core
    
    @inline(__always)
    private func generate4ChCore(_ buffer: inout [Int16]) {
        guard buffer.count >= 4 else { return }

        buffer[1] = clipSample(mixBuf1)
        buffer[3] = clipSample(mixBuf3)

        slots.withUnsafeBufferPointer { slotsPtr in
            // First half-cycle: process all 36 slots
            var slotIdx = 0
            while slotIdx < 36 {
                processSlot(slotsPtr[slotIdx])
                slotIdx += 1
            }

            // First mix pass (cha/chc)
            var mix0: Int32 = 0
            var mix1: Int32 = 0

            channels.withUnsafeBufferPointer { channelsPtr in
                var chIdx = 0
                while chIdx < 18 {
                    let ch = channelsPtr[chIdx]
                    var accm = 0
                    if ch.outSlot0 >= 0 { accm &+= Int(slotsPtr[Int(ch.outSlot0)].out) }
                    if ch.outSlot1 >= 0 { accm &+= Int(slotsPtr[Int(ch.outSlot1)].out) }
                    if ch.outSlot2 >= 0 { accm &+= Int(slotsPtr[Int(ch.outSlot2)].out) }
                    if ch.outSlot3 >= 0 { accm &+= Int(slotsPtr[Int(ch.outSlot3)].out) }
                    mix0 = mix0 &+ Int32(Int16(truncatingIfNeeded: accm & Int(ch.cha)))
                    mix1 = mix1 &+ Int32(Int16(truncatingIfNeeded: accm & Int(ch.chc)))
                    chIdx += 1
                }
            }

            mixBuf0 = mix0
            mixBuf2 = mix1

            buffer[0] = clipSample(mixBuf0)
            buffer[2] = clipSample(mixBuf2)

            // Second half-cycle: process all 36 slots again
            slotIdx = 0
            while slotIdx < 36 {
                processSlot(slotsPtr[slotIdx])
                slotIdx += 1
            }

            // Second mix pass (chb/chd) - uses updated operator outputs from second half-cycle
            mix0 = 0
            mix1 = 0

            channels.withUnsafeBufferPointer { channelsPtr in
                var chIdx = 0
                while chIdx < 18 {
                    let ch = channelsPtr[chIdx]
                    var accm = 0
                    if ch.outSlot0 >= 0 { accm &+= Int(slotsPtr[Int(ch.outSlot0)].out) }
                    if ch.outSlot1 >= 0 { accm &+= Int(slotsPtr[Int(ch.outSlot1)].out) }
                    if ch.outSlot2 >= 0 { accm &+= Int(slotsPtr[Int(ch.outSlot2)].out) }
                    if ch.outSlot3 >= 0 { accm &+= Int(slotsPtr[Int(ch.outSlot3)].out) }
                    mix0 = mix0 &+ Int32(Int16(truncatingIfNeeded: accm & Int(ch.chb)))
                    mix1 = mix1 &+ Int32(Int16(truncatingIfNeeded: accm & Int(ch.chd)))
                    chIdx += 1
                }
            }

            // Store for output at the START of the next call (one-sample delay on B/D channels,
            // matching the original NukedOPL3 hardware behavior)
            mixBuf1 = mix0
            mixBuf3 = mix1
        }
        
        // LFO advance
        OPL3Lfo.advance(self)
        
        timer = timer &+ 1
        
        // Envelope generator timing
        if egState != 0 {
            var shift: UInt8 = 0
            while shift < 13 && ((egTimer >> shift) & 1) == 0 {
                shift += 1
            }
            
            if shift > 12 {
                egAdd = 0
            } else {
                egAdd = shift + 1
            }
            
            egTimerLow = UInt8(egTimer & 0x03)
        }
        
        if egTimerRem != 0 || egState != 0 {
            if egTimer == 0x0FFFFFFFF {
                egTimer = 0
                egTimerRem = 1
            } else {
                egTimer += 1
                egTimerRem = 0
            }
        }
        
        egState ^= 1
        
        // Process write buffer — skip the heap load entirely when the ring is empty.
        // The ring is empty when current has caught up to (last + 1). writeBufferSize is a
        // power of 2 (1024), so the wrap uses a cheap bitwise mask instead of a modulo.
        if writeBufferCurrent != (writeBufferLast &+ 1) & UInt32(Self.writeBufferSize - 1) {
            while true {
                let entry = writeBuffer[Int(writeBufferCurrent)]
                if entry.time > writeBufferSampleCounter {
                    break
                }
                if (entry.register & 0x200) == 0 {
                    break
                }

                let reg = entry.register & 0x1FF

                writeBuffer[Int(writeBufferCurrent)].register = reg
                writeRegisterInternal(reg, entry.data)
                writeBufferCurrent = (writeBufferCurrent + 1) % UInt32(Self.writeBufferSize)
            }
        }

        writeBufferSampleCounter += 1
    }
    
    /// Core stereo compute step: processes all 36 slots, mixes, and stores the result
    /// into the `sampleL`/`sampleR` scalar fields. Advances LFO, EG, and write-buffer state.
    /// Called by both `generateCore` (external buffer path) and `generateResampledCore`
    /// (resampler path). Using scalar output fields avoids passing an inout heap array
    /// through the resampler, eliminating COW checks and bounds-checked subscripts.
    @inline(__always)
    private func generateCoreCompute() {
        slots.withUnsafeBufferPointer { slotsPtr in
            var slotIdx = 0

            while slotIdx < 36 {
                processSlot(slotsPtr[slotIdx])
                slotIdx += 1
            }

            var mixL: Int32 = 0
            var mixR: Int32 = 0

            channels.withUnsafeBufferPointer { channelsPtr in
                var chIdx = 0

                while chIdx < 18 {
                    let ch = channelsPtr[chIdx]

                    var accm = 0
                    if ch.outSlot0 >= 0 { accm &+= Int(slotsPtr[Int(ch.outSlot0)].out) }
                    if ch.outSlot1 >= 0 { accm &+= Int(slotsPtr[Int(ch.outSlot1)].out) }
                    if ch.outSlot2 >= 0 { accm &+= Int(slotsPtr[Int(ch.outSlot2)].out) }
                    if ch.outSlot3 >= 0 { accm &+= Int(slotsPtr[Int(ch.outSlot3)].out) }

                    mixL = mixL &+ Int32(Int16(truncatingIfNeeded: accm & Int(ch.cha)))
                    mixR = mixR &+ Int32(Int16(truncatingIfNeeded: accm & Int(ch.chb)))
                    chIdx += 1
                }
            }

            sampleL = clipSample(mixL)
            sampleR = clipSample(mixR)
        }

        // LFO advance
        OPL3Lfo.advance(self)

        timer = timer &+ 1

        // Envelope generator timing
        if egState != 0 {
            var shift: UInt8 = 0
            while shift < 13 && ((egTimer >> shift) & 1) == 0 {
                shift += 1
            }

            if shift > 12 {
                egAdd = 0
            } else {
                egAdd = shift + 1
            }

            egTimerLow = UInt8(egTimer & 0x03)
        }

        if egTimerRem != 0 || egState != 0 {
            if egTimer == 0x0FFFFFFFF {
                egTimer = 0
                egTimerRem = 1
            } else {
                egTimer += 1
                egTimerRem = 0
            }
        }

        egState ^= 1

        // Process write buffer — skip the heap load entirely when the ring is empty.
        // The ring is empty when current has caught up to (last + 1). writeBufferSize is a
        // power of 2 (1024), so the wrap uses a cheap bitwise mask instead of a modulo.
        if writeBufferCurrent != (writeBufferLast &+ 1) & UInt32(Self.writeBufferSize - 1) {
            while true {
                let entry = writeBuffer[Int(writeBufferCurrent)]
                if entry.time > writeBufferSampleCounter {
                    break
                }
                if (entry.register & 0x200) == 0 {
                    break
                }

                let reg = entry.register & 0x1FF

                writeBuffer[Int(writeBufferCurrent)].register = reg
                writeRegisterInternal(reg, entry.data)
                writeBufferCurrent = (writeBufferCurrent + 1) % UInt32(Self.writeBufferSize)
            }
        }

        writeBufferSampleCounter += 1
    }

    /// Stereo generation matching OPL3_Generate: each slot processed ONCE per output sample.
    /// This is the correct path for standard stereo output. OPL3_Generate4Ch processes each
    /// slot TWICE (for 4-channel output), which doubles the phase advance and shifts all
    /// frequencies up one octave — incorrect for stereo playback.
    @inline(__always)
    private func generateCore(_ buffer: inout [Int16]) {
        guard buffer.count >= 2 else { return }
        generateCoreCompute()
        buffer[0] = sampleL
        buffer[1] = sampleR
    }
    
    @inline(__always)
    private func generate4ChResampledCore(_ buffer: inout [Int16]) {
        guard buffer.count >= 4 else { return }
        
        while rateRatio != 0 && sampleCounter >= rateRatio {
            oldSamples4ch[0] = samples4ch[0]
            oldSamples4ch[1] = samples4ch[1]
            oldSamples4ch[2] = samples4ch[2]
            oldSamples4ch[3] = samples4ch[3]
            
            generate4ChCore(&samples4ch)
            sampleCounter -= rateRatio
        }
        
        if rateRatio != 0 {
            let num0 = Int32(oldSamples4ch[0]) * (rateRatio - sampleCounter) + Int32(samples4ch[0]) * sampleCounter
            let num1 = Int32(oldSamples4ch[1]) * (rateRatio - sampleCounter) + Int32(samples4ch[1]) * sampleCounter
            let num2 = Int32(oldSamples4ch[2]) * (rateRatio - sampleCounter) + Int32(samples4ch[2]) * sampleCounter
            let num3 = Int32(oldSamples4ch[3]) * (rateRatio - sampleCounter) + Int32(samples4ch[3]) * sampleCounter
            if rateRatioShift >= 0 {
                buffer[0] = Int16(num0 >> rateRatioShift)
                buffer[1] = Int16(num1 >> rateRatioShift)
                buffer[2] = Int16(num2 >> rateRatioShift)
                buffer[3] = Int16(num3 >> rateRatioShift)
            } else {
                buffer[0] = Int16(num0 / rateRatio)
                buffer[1] = Int16(num1 / rateRatio)
                buffer[2] = Int16(num2 / rateRatio)
                buffer[3] = Int16(num3 / rateRatio)
            }
        } else {
            buffer[0] = samples4ch[0]
            buffer[1] = samples4ch[1]
            buffer[2] = samples4ch[2]
            buffer[3] = samples4ch[3]
        }
        
        sampleCounter += 1 << Self.resampleFractionBits
    }
    
    /// Stereo resampled generation: uses scalar `sampleL`/`sampleR`/`oldSampleL`/`oldSampleR`
    /// instead of heap-allocated arrays, eliminating COW checks and subscript bounds checks
    /// on the hot interpolation path.
    @inline(__always)
    private func generateResampledCore(_ buffer: inout [Int16]) {
        guard buffer.count >= 2 else { return }

        while rateRatio != 0 && sampleCounter >= rateRatio {
            oldSampleL = sampleL
            oldSampleR = sampleR

            generateCoreCompute()
            sampleCounter -= rateRatio
        }

        if rateRatio != 0 {
            let numL = Int32(oldSampleL) * (rateRatio - sampleCounter) + Int32(sampleL) * sampleCounter
            let numR = Int32(oldSampleR) * (rateRatio - sampleCounter) + Int32(sampleR) * sampleCounter
            if rateRatioShift >= 0 {
                buffer[0] = Int16(numL >> rateRatioShift)
                buffer[1] = Int16(numR >> rateRatioShift)
            } else {
                buffer[0] = Int16(numL / rateRatio)
                buffer[1] = Int16(numR / rateRatio)
            }
        } else {
            buffer[0] = sampleL
            buffer[1] = sampleR
        }

        sampleCounter += 1 << Self.resampleFractionBits
    }

    /// Resampled stereo generation that writes directly to two scalar `inout` params instead of
    /// an `inout [Int16]` buffer. Eliminates the COW uniqueness check and two bounds-checked
    /// subscripts that occur every call when writing through a heap-allocated array.
    /// Called by `OPL3Fm.generateFrames` — the audio playback hot path.
    @inline(__always)
    func generateResampledDirect(left: inout Int16, right: inout Int16) {
        while rateRatio != 0 && sampleCounter >= rateRatio {
            oldSampleL = sampleL
            oldSampleR = sampleR
            generateCoreCompute()
            sampleCounter -= rateRatio
        }

        if rateRatio != 0 {
            let numL = Int32(oldSampleL) * (rateRatio - sampleCounter) + Int32(sampleL) * sampleCounter
            let numR = Int32(oldSampleR) * (rateRatio - sampleCounter) + Int32(sampleR) * sampleCounter
            if rateRatioShift >= 0 {
                left = Int16(numL >> rateRatioShift)
                right = Int16(numR >> rateRatioShift)
            } else {
                left = Int16(numL / rateRatio)
                right = Int16(numR / rateRatio)
            }
        } else {
            left = sampleL
            right = sampleR
        }

        sampleCounter += 1 << Self.resampleFractionBits
    }

    // MARK: - Reset
    
    private func resetInternal(_ sampleRate: UInt32) {
        timer = 0
        egTimer = 0
        egTimerRem = 0
        egState = 0
        egAdd = 0
        egTimerLow = 0
        newM = 0
        nts = 0
        rhythm = 0
        
        OPL3Lfo.reset(self)
        
        noise = 1
        zeroMod = 0
        mixBuf0 = 0
        mixBuf1 = 0
        mixBuf2 = 0
        mixBuf3 = 0
        
        rhythmHihatBit2 = 0
        rhythmHihatBit3 = 0
        rhythmHihatBit7 = 0
        rhythmHihatBit8 = 0
        rhythmTomBit3 = 0
        rhythmTomBit5 = 0
        
        rateRatio = sampleRate == 0 ? 1 : Int32((UInt32(sampleRate) << Self.resampleFractionBits) / 49716)
        if rateRatio == 0 {
            rateRatio = 1
        }
        // Precompute log2(rateRatio) for the common power-of-2 case (e.g. 49716 Hz → 1024 = 2^10).
        // A bit-shift replaces the two integer divisions per output sample in the hot resampler path.
        if rateRatio > 0 && (rateRatio & (rateRatio - 1)) == 0 {
            var shift: Int32 = 0
            var tmp = rateRatio
            while tmp > 1 { tmp >>= 1; shift += 1 }
            rateRatioShift = shift
        } else {
            rateRatioShift = -1
        }
        
        sampleCounter = 0
        sampleL = 0
        sampleR = 0
        oldSampleL = 0
        oldSampleR = 0
        samples4ch = [0, 0, 0, 0]
        oldSamples4ch = [0, 0, 0, 0]
        
        writeBufferSampleCounter = 0
        // Both start at 0; first write goes to index 1
        // Set current to 1 so processing starts where writes begin
        writeBufferCurrent = 1
        writeBufferLast = 0
        writeBufferLastTime = 0
        
        var wbIdx = 0
        while wbIdx < writeBuffer.count {
            writeBuffer[wbIdx].register = 0
            writeBuffer[wbIdx].data = 0
            writeBuffer[wbIdx].time = 0
            wbIdx += 1
        }
        
        // Reset slots
        var slotIndex = 0
        while slotIndex < slots.count {
            let slot = slots[slotIndex]
            slot.channel = nil
            slot.chip = self
            slot.modulationSource = .zero
            slot.previousOutputSample = 0
            slot.out = 0
            slot.feedbackModifiedSignal = 0
            slot.envelopeGeneratorOutput = 0x1FF
            slot.envelopeGeneratorLevel = 0x1FF
            slot.envelopeGeneratorIncrement = 0
            slot.envelopeGeneratorState = OPL3EnvelopeGeneratorStage.release.rawValue
            slot.effectiveEnvelopeRateIndex = 0
            slot.effectiveKeyScaleLevel = 0
            slot.tremoloEnabled = false
            slot.regVibrato = 0
            slot.regOperatorType = 0
            slot.regKeyScaleRate = 0
            slot.regFrequencyMultiplier = 0
            slot.regKeyScaleLevel = 0
            slot.regTotalLevel = 0
            slot.regAttackRate = 0
            slot.regDecayRate = 0
            slot.regSustainLevel = 0
            slot.regReleaseRate = 0
            slot.regWaveformSelect = 0
            slot.regKeyState = 0
            slot.regPhaseResetRequest = 0
            slot.regPhaseGeneratorAccumulator = 0
            slot.phaseGeneratorOutput = 0
            slot.slotIndex = UInt8(slotIndex)
            slotIndex += 1
        }
        
        // Reset channels
        var channelIndex = 0
        while channelIndex < channels.count {
            let channel = channels[channelIndex]
            let localSlot = Int(OPL3Tables.readChannelSlot(channelIndex))
            
            channel.slotz[0] = slots[localSlot]
            channel.slotz[1] = slots[localSlot + 3]
            channel.slotz[0].channel = channel
            channel.slotz[1].channel = channel
            channel.slotz[0].chip = self
            channel.slotz[1].chip = self
            channel.pair = nil
            
            let mod9 = channelIndex % 9
            if mod9 < 3 {
                channel.pair = channels[channelIndex + 3]
            } else if mod9 < 6 {
                channel.pair = channels[channelIndex - 3]
            }
            
            channel.chip = self
            channel.outSlot0 = -1
            channel.outSlot1 = -1
            channel.outSlot2 = -1
            channel.outSlot3 = -1
            channel.channelType = .twoOp
            channel.fNumber = 0
            channel.block = 0
            channel.feedback = 0
            channel.connection = 0
            channel.algorithm = 0
            channel.keyScaleValue = 0
            channel.cha = 0xFFFF
            channel.chb = 0xFFFF
            channel.chc = 0
            channel.chd = 0
            channel.channelNumber = UInt8(channelIndex)
            channel.previousKeyOn = false
            
            channelSetupAlgorithm(channel)
            channelIndex += 1
        }
    }
    
    // MARK: - Register Write
    
    private func writeRegisterInternal(_ register: UInt16, _ value: UInt8) {
        let high = UInt8((register >> 8) & 0x01)
        let regm = UInt8(register & 0xFF)
        
        let slotBase = high != 0 ? 18 : 0
        let channelBase = high != 0 ? 9 : 0
        
        switch regm & 0xF0 {
        case 0x00:
            if high != 0 {
                switch regm & 0x0F {
                case 0x04:
                    channelSet4Op(value)
                case 0x05:
                    newM = value & 0x01
                default:
                    break
                }
            } else {
                if (regm & 0x0F) == 0x08 {
                    nts = (value >> 6) & 0x01
                }
            }
            
        case 0x20, 0x30:
            let slotIndex = OPL3Tables.readAddressDecodeSlot(Int(regm) & 0x1F)
            if slotIndex >= 0 {
                slotWrite20(slots[slotBase + Int(slotIndex)], value)
            }
            
        case 0x40, 0x50:
            let slotIndex = OPL3Tables.readAddressDecodeSlot(Int(regm) & 0x1F)
            if slotIndex >= 0 {
                let slot = slots[slotBase + Int(slotIndex)]
                let _ = value & 0x3F // tl
                slotWrite40(slot, value)
            }
            
        case 0x60, 0x70:
            let slotIndex = OPL3Tables.readAddressDecodeSlot(Int(regm) & 0x1F)
            if slotIndex >= 0 {
                slotWrite60(slots[slotBase + Int(slotIndex)], value)
            }
            
        case 0x80, 0x90:
            let slotIndex = OPL3Tables.readAddressDecodeSlot(Int(regm) & 0x1F)
            if slotIndex >= 0 {
                slotWrite80(slots[slotBase + Int(slotIndex)], value)
            }
            
        case 0xE0, 0xF0:
            let slotIndex = OPL3Tables.readAddressDecodeSlot(Int(regm) & 0x1F)
            if slotIndex >= 0 {
                slotWriteE0(slots[slotBase + Int(slotIndex)], value)
            }
            
        case 0xA0:
            if (regm & 0x0F) < 9 {
                let chIdx = channelBase + Int(regm & 0x0F)
                let channel = channels[chIdx]
                channelWriteA0(channel, value)
            }

        case 0xB0:
            if regm == 0xBD && high == 0 {
                OPL3Lfo.configureDepth(self, value)
                channelUpdateRhythm(value)
            } else if (regm & 0x0F) < 9 {
                let chIdx = channelBase + Int(regm & 0x0F)
                let channel = channels[chIdx]
                let keyOn = (value & 0x20) != 0
                let wasKeyOn = channel.previousKeyOn
                channelWriteB0(channel, value)
                
                if keyOn {
                    channelKeyOn(channel)
                } else {
                    channelKeyOff(channel)
                }

                channel.previousKeyOn = keyOn
            }
            
        case 0xC0:
            if (regm & 0x0F) < 9 {
                channelWriteC0(channels[channelBase + Int(regm & 0x0F)], value)
            }
            
        default:
            break
        }
    }
    
    // MARK: - Buffered Register Write
    
    private func writeRegisterBufferedInternal(_ register: UInt16, _ value: UInt8) {
        // Calculate the NEXT index first (matching original NukedOPL3)
        let writebufLast = Int((writeBufferLast + 1) % UInt32(Self.writeBufferSize))


        // Check if there's an unprocessed entry at that index
        let entry = writeBuffer[writebufLast]
        if (entry.register & 0x200) != 0 {
            // Process old entry immediately before overwriting
            writeRegisterInternal(entry.register & 0x1FF, entry.data)
            writeBufferCurrent = UInt32((writebufLast + 1) % Self.writeBufferSize)
            writeBufferSampleCounter = entry.time
        }

        // Write new entry to the calculated index
        writeBuffer[writebufLast].register = register | 0x200
        writeBuffer[writebufLast].data = value

        var time1 = writeBufferLastTime + UInt64(Self.writeBufferDelay)
        let time2 = writeBufferSampleCounter

        if time1 < time2 {
            time1 = time2
        }

        writeBuffer[writebufLast].time = time1
        writeBufferLastTime = time1
        writeBufferLast = UInt32(writebufLast)
    }
    
    // MARK: - Stream Generation
    
    private func generate4ChStreamCore(_ stream1: inout [Int16], _ stream2: inout [Int16]) {
        let frames = min(stream1.count, stream2.count) / 2
        if frames == 0 { return }
        
        var temp: [Int16] = [0, 0, 0, 0]
        
        var idx = 0
        while idx < frames {
            generate4ChResampledCore(&temp)
            let offset = idx * 2
            stream1[offset] = temp[0]
            stream1[offset + 1] = temp[1]
            stream2[offset] = temp[2]
            stream2[offset + 1] = temp[3]
            idx += 1
        }
    }
    
    private func generateStreamCore(_ stream: inout [Int16]) {
        let frames = stream.count / 2
        if frames == 0 { return }
        
        //var temp: [Int16] = [0, 0, 0, 0]
        var temp: [Int16] = [0, 0]
        
        var idx = 0
        while idx < frames {
            generateResampledCore(&temp)
            let offset = idx * 2
            stream[offset] = temp[0]
            stream[offset + 1] = temp[1]
            idx += 1
        }
    }
}
