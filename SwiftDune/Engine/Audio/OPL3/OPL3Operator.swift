//
//  OPL3Operator.swift
//  SwiftDune
//
//  Ported from Nuked OPL3 (Spice86 C# implementation)
//  Original C code: Copyright (C) 2013-2020 Nuke.YKT
//  SPDX-License-Identifier: LGPL-2.1
//
//  Created by Christophe Buguet on 04/02/2026.
//

import Foundation

/// Envelope generator stage
public enum OPL3EnvelopeGeneratorStage: UInt8 {
    case attack = 0
    case decay = 1
    case sustain = 2
    case release = 3

    var description: String {
        switch self {
        case .attack: return "ATK"
        case .decay: return "DEC"
        case .sustain: return "SUS"
        case .release: return "REL"
        }
    }
}

/// OPL3 Operator (Slot) - represents a single FM operator
public final class OPL3Operator {
    // MARK: - Envelope Generator State
    
    /// Effective envelope rate index for current state (after KSR/KSL computations)
    var effectiveEnvelopeRateIndex: UInt8 = 0
    
    /// Effective Key-Scale Level value combined with note/f-number (attenuation offset applied to TL)
    var effectiveKeyScaleLevel: UInt8 = 0
    
    /// Envelope generator increment per sample tick (rate step accumulator)
    var envelopeGeneratorIncrement: UInt8 = 0
    
    /// Envelope generator current output level (attenuation value used to scale operator output)
    public var envelopeGeneratorLevel: UInt16 = 0x1FF
    
    /// Envelope generator raw output routed to mixer (pre-scaling)
    public var envelopeGeneratorOutput: UInt16 = 0x1FF
    
    /// Envelope generator state: 0=Attack, 1=Decay, 2=Sustain, 3=Release
    public var envelopeGeneratorState: UInt8 = UInt8(OPL3EnvelopeGeneratorStage.release.rawValue)
    
    // MARK: - Output Signals
    
    /// Feedback-modified signal fed back into the operator (used when operator is carrier with feedback)
    var feedbackModifiedSignal: Int16 = 0
    
    /// External modulation source providing the modulator signal for this operator
    var modulationSource: OPL3SignalSource = .zero
    
    /// Current operator audio output sample (linear, post-EG, post-waveform)
    var out: Int16 = 0
    
    /// Phase generator output phase used to index waveform (reduced bits of PgPhase)
    var phaseGeneratorOutput: UInt16 = 0
    
    /// Previous output sample (used for feedback calculation)
    var previousOutputSample: Int16 = 0
    
    // MARK: - Registers
    
    /// Register: AR (Attack Rate). 0..15 = Attack speed (0=no attack, 15=fastest)
    public var regAttackRate: UInt8 = 0
    
    /// Register: DR (Decay Rate). 0..15 = Decay speed from peak to sustain level
    public var regDecayRate: UInt8 = 0
    
    /// Register: MULT (frequency multiplier). 0..15 = Multiplier table index
    public var regFrequencyMultiplier: UInt8 = 0
    
    /// Register: KSL (Key Scale Level). 0..3 = Key-scaling curve amount applied to TL
    public var regKeyScaleLevel: UInt8 = 0
    
    /// Register: KSR (Key Scale Rate). 0=Rate not scaled, 1=Rate scaled by key number
    public var regKeyScaleRate: UInt8 = 0
    
    /// Internal key state for this operator. 0=Key off, non-zero=Key on
    var regKeyState: UInt8 = 0
    
    /// Register: Operator type (modulator/carrier selection)
    var regOperatorType: UInt8 = 0
    
    /// Phase generator accumulator (phase counter in fixed-point domain)
    var regPhaseGeneratorAccumulator: UInt32 = 0
    
    /// Phase generator reset request/flag (set when key-on or algorithm requires resetting phase)
    var regPhaseResetRequest: UInt32 = 0
    
    /// Register: RR (Release Rate). 0..15 = Release speed after key-off
    public var regReleaseRate: UInt8 = 0
    
    /// Register: SL (Sustain Level). 0..15 = Sustain level step
    public var regSustainLevel: UInt8 = 0
    
    /// Register: TL (Total Level). 0..63 = Output attenuation level (0=loudest)
    public var regTotalLevel: UInt8 = 0
    
    /// Register: VIB (vibrato enable). 0=Off, 1=On
    var regVibrato: UInt8 = 0
    
    /// Register: WF (Waveform select). 0..7 = Waveform index
    var regWaveformSelect: UInt8 = 0
    
    /// Slot index within the chip (0-based operator number)
    var slotIndex: UInt8 = 0
    
    // MARK: - References
    
    /// Back-reference to the owning channel this operator belongs to
    unowned(unsafe)  var channel: OPL3Channel!
    
    /// Back-reference to the parent chip instance
    unowned(unsafe)  var chip: OPL3Chip!
    
    /// Indicates whether the tremolo LFO is applied to this operator
    var tremoloEnabled: Bool = false
    
    // MARK: - Computed Properties
    
    /// Value source exposing current operator output sample
    var outputSignal: OPL3SignalSource {
        return OPL3SignalSource.fromOutput(self)
    }
    
    /// Value source exposing feedback-modified signal
    var feedbackSignal: OPL3SignalSource {
        return OPL3SignalSource.fromFeedback(self)
    }
    
    // MARK: - Initialization
    
    init() {}
}
