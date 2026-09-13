//
//  OPL3Envelope.swift
//  SwiftDune
//
//  Ported from Nuked OPL3 (Spice86 C# implementation)
//  Original C code: Copyright (C) 2013-2020 Nuke.YKT
//  SPDX-License-Identifier: LGPL-2.1
//
//  Created by Christophe Buguet on 04/02/2026.
//

import Foundation

/// Envelope generator functions for OPL3 emulation
struct OPL3Envelope {
    
    // MARK: - Envelope Calculation Helper
    
    @inline(__always)
    private static func envelopeCalcExp(_ level: UInt32) -> Int16 {
        var level = level
        if level > 0x1FFF {
            level = 0x1FFF
        }
        let value = Int(OPL3Tables.readExp(Int(level & 0xFF)) << 1) >> Int(level >> 8)
        return Int16(truncatingIfNeeded: value)
    }
    
    // MARK: - Waveform Sin Functions
    
    @inline(__always)
    private static func envelopeCalcSin0(_ phase: UInt16, _ envelope: UInt16) -> Int16 {
        var neg: UInt16 = 0
        let phase = phase & 0x3FF
        
        if (phase & 0x200) != 0 {
            neg = 0xFFFF
        }
        
        let output: UInt16 = (phase & 0x100) != 0
            ? OPL3Tables.readLogSin(Int(phase & 0xFF) ^ 0xFF)
            : OPL3Tables.readLogSin(Int(phase & 0xFF))
        
        let sample = UInt16(truncatingIfNeeded: envelopeCalcExp(UInt32(output) + (UInt32(envelope) << 3)))
        return Int16(bitPattern: sample ^ neg)
    }
    
    @inline(__always)
    private static func envelopeCalcSin1(_ phase: UInt16, _ envelope: UInt16) -> Int16 {
        var output: UInt16
        let phase = phase & 0x3FF
        
        if (phase & 0x200) != 0 {
            output = 0x1000
        } else if (phase & 0x100) != 0 {
            output = OPL3Tables.readLogSin(Int(phase & 0xFF) ^ 0xFF)
        } else {
            output = OPL3Tables.readLogSin(Int(phase & 0xFF))
        }
        
        return envelopeCalcExp(UInt32(output) + (UInt32(envelope) << 3))
    }
    
    @inline(__always)
    private static func envelopeCalcSin2(_ phase: UInt16, _ envelope: UInt16) -> Int16 {
        let phase = phase & 0x3FF
        
        let output: UInt16 = (phase & 0x100) != 0
            ? OPL3Tables.readLogSin(Int(phase & 0xFF) ^ 0xFF)
            : OPL3Tables.readLogSin(Int(phase & 0xFF))
        
        return envelopeCalcExp(UInt32(output) + (UInt32(envelope) << 3))
    }
    
    @inline(__always)
    private static func envelopeCalcSin3(_ phase: UInt16, _ envelope: UInt16) -> Int16 {
        var output: UInt16
        let phase = phase & 0x3FF
        
        if (phase & 0x100) != 0 {
            output = 0x1000
        } else {
            output = OPL3Tables.readLogSin(Int(phase & 0xFF))
        }
        
        return envelopeCalcExp(UInt32(output) + (UInt32(envelope) << 3))
    }
    
    @inline(__always)
    private static func envelopeCalcSin4(_ phase: UInt16, _ envelope: UInt16) -> Int16 {
        var output: UInt16
        let neg: UInt16 = 0xFFFF
        let phase = phase & 0x3FF
        
        if (phase & 0x100) != 0 {
            output = UInt16(((Int(phase) & 0xFF) ^ 0xFF) << 4)
        } else {
            output = UInt16((Int(phase) & 0xFF) << 4)
        }
        
        let sample = UInt16(truncatingIfNeeded: envelopeCalcExp(UInt32(output) + (UInt32(envelope) << 3)))
        return Int16(bitPattern: sample ^ neg)
    }
    
    @inline(__always)
    private static func envelopeCalcSin5(_ phase: UInt16, _ envelope: UInt16) -> Int16 {
        var output: UInt16
        var phase = phase & 0x3FF
        
        if (phase & 0x200) != 0 {
            phase ^= 0x3FF
        }
        
        if (phase & 0x100) != 0 {
            output = UInt16(((Int(phase) & 0xFF) ^ 0xFF) << 4)
        } else {
            output = UInt16((Int(phase) & 0xFF) << 4)
        }
        
        return envelopeCalcExp(UInt32(output) + (UInt32(envelope) << 3))
    }
    
    @inline(__always)
    private static func envelopeCalcSin6(_ phase: UInt16, _ envelope: UInt16) -> Int16 {
        var output: UInt16
        let neg: UInt16 = 0xFFFF
        var phase = phase & 0x3FF
        
        if (phase & 0x200) != 0 {
            output = 0x1000
        } else if (phase & 0x100) != 0 {
            output = OPL3Tables.readLogSin(Int(phase & 0xFF) ^ 0xFF)
        } else {
            output = OPL3Tables.readLogSin(Int(phase & 0xFF))
        }
        
        phase = (phase &+ 0x80) & 0x3FF
        output = output &+ OPL3Tables.readLogSin(Int(phase & 0xFF))
        
        let sample = UInt16(truncatingIfNeeded: envelopeCalcExp(UInt32(output) + (UInt32(envelope) << 3)))
        return Int16(bitPattern: sample ^ neg)
    }
    
    @inline(__always)
    private static func envelopeCalcSin7(_ phase: UInt16, _ envelope: UInt16) -> Int16 {
        var output: UInt16
        var phase = phase & 0x3FF
        
        if (phase & 0x200) != 0 {
            output = 0x1000
        } else if (phase & 0x100) != 0 {
            output = OPL3Tables.readLogSin(Int(phase & 0xFF) ^ 0xFF)
        } else {
            output = OPL3Tables.readLogSin(Int(phase & 0xFF))
        }
        
        phase = (phase &+ 0x80) & 0x3FF
        output = output &+ OPL3Tables.readLogSin(Int(phase & 0xFF))
        
        return envelopeCalcExp(UInt32(output) + (UInt32(envelope) << 3))
    }
    
    // MARK: - Waveform Generation
    
    /// Generates waveform output for the given operator
    @inline(__always)
    static func generateWaveform(_ slot: OPL3Operator) -> Int16 {
        let index = Int(slot.regWaveformSelect & 0x07)
        let mod = slot.modulationSource.read()
        let phase = UInt16(truncatingIfNeeded: Int32(slot.phaseGeneratorOutput) + Int32(mod))
        
        switch index {
        case 0: return envelopeCalcSin0(phase, slot.envelopeGeneratorLevel)
        case 1: return envelopeCalcSin1(phase, slot.envelopeGeneratorLevel)
        case 2: return envelopeCalcSin2(phase, slot.envelopeGeneratorLevel)
        case 3: return envelopeCalcSin3(phase, slot.envelopeGeneratorLevel)
        case 4: return envelopeCalcSin4(phase, slot.envelopeGeneratorLevel)
        case 5: return envelopeCalcSin5(phase, slot.envelopeGeneratorLevel)
        case 6: return envelopeCalcSin6(phase, slot.envelopeGeneratorLevel)
        case 7: return envelopeCalcSin7(phase, slot.envelopeGeneratorLevel)
        default: return 0
        }
    }
    
    // MARK: - Key Scale Level Update
    
    /// Updates the key scale level for an operator
    static func envelopeUpdateKsl(_ slot: OPL3Operator) {
        let channel = slot.channel!
        var value = Int16(OPL3Tables.readKeyScaleLevel(Int(channel.fNumber) >> 6) << 2) - Int16((0x08 - Int(channel.block)) << 5)
      
        if value < 0 {
            value = 0
        }
      
        slot.effectiveKeyScaleLevel = UInt8(value)
    }
    
    // MARK: - Envelope Calculation
    
    /// Calculates envelope for the given operator
    @inline(__always)
    static func envelopeCalc(_ slot: OPL3Operator) {
        let chip = slot.chip!
        let channel = slot.channel!

        var regRate: UInt8 = 0
        var shift: UInt8 = 0
        var egIncrement: Int = 0
        var reset: UInt8 = 0
        
        let tremoloValue: UInt8 = slot.tremoloEnabled ? chip.tremolo : 0
        slot.envelopeGeneratorLevel = UInt16(
            Int(slot.envelopeGeneratorOutput) +
            (Int(slot.regTotalLevel) << 2) +
            (Int(slot.effectiveKeyScaleLevel) >> Int(OPL3Tables.readKeyScaleShift(Int(slot.regKeyScaleLevel)))) +
            Int(tremoloValue)
        )
        
        if slot.regKeyState != 0 && slot.envelopeGeneratorState == OPL3EnvelopeGeneratorStage.release.rawValue {
            reset = 1
            regRate = slot.regAttackRate
        } else {
            switch slot.envelopeGeneratorState {
            case OPL3EnvelopeGeneratorStage.attack.rawValue:
                regRate = slot.regAttackRate
            case OPL3EnvelopeGeneratorStage.decay.rawValue:
                regRate = slot.regDecayRate
            case OPL3EnvelopeGeneratorStage.sustain.rawValue:
                if slot.regOperatorType == 0 {
                    regRate = slot.regReleaseRate
                }
            default: // Release
                regRate = slot.regReleaseRate
            }
        }
        
        slot.regPhaseResetRequest = UInt32(reset)
        let keyScale = channel.keyScaleValue >> ((slot.regKeyScaleRate ^ 1) << 1)
        let nonZero: UInt8 = regRate != 0 ? 1 : 0
        let rate = keyScale + (regRate << 2)
        var rateHi = rate >> 2
        let rateLo = rate & 0x03
        
        if (rateHi & 0x10) != 0 {
            rateHi = 0x0F
        }
        
        let egShift = rateHi &+ chip.egAdd
        
        if nonZero != 0 {
            if rateHi < 12 {
                if chip.egState != 0 {
                    switch egShift {
                    case 12:
                        shift = 1
                    case 13:
                        shift = (rateLo >> 1) & 0x01
                    case 14:
                        shift = rateLo & 0x01
                    default:
                        break
                    }
                }
            } else {
                shift = (rateHi & 0x03) &+ OPL3Tables.egIncrementSteps[Int(rateLo)][Int(chip.egTimerLow)]
                if (shift & 0x04) != 0 {
                    shift = 0x03
                }
                if shift == 0 {
                    shift = chip.egState
                }
            }
        }
        
        var egRout = slot.envelopeGeneratorOutput
        var egOff: UInt8 = 0
        
        // Instant attack
        if reset != 0 && rateHi == 0x0F {
            egRout = 0x00
        }
        
        // Envelope off check
        if (slot.envelopeGeneratorOutput & 0x1F8) == 0x1F8 {
            egOff = 1
        }
        
        if slot.envelopeGeneratorState != OPL3EnvelopeGeneratorStage.attack.rawValue && reset == 0 && egOff != 0 {
            egRout = 0x1FF
        }
        
        switch slot.envelopeGeneratorState {
        case OPL3EnvelopeGeneratorStage.attack.rawValue:
            if slot.envelopeGeneratorOutput == 0 {
                slot.envelopeGeneratorState = OPL3EnvelopeGeneratorStage.decay.rawValue
            } else if slot.regKeyState != 0 && shift > 0 && rateHi != 0x0F {
                egIncrement = ~Int(slot.envelopeGeneratorOutput) >> (4 - Int(shift))
            }
            
        case OPL3EnvelopeGeneratorStage.decay.rawValue:
            if slot.envelopeGeneratorOutput >> 4 == UInt16(slot.regSustainLevel) {
                slot.envelopeGeneratorState = OPL3EnvelopeGeneratorStage.sustain.rawValue
            } else if egOff == 0 && reset == 0 && shift > 0 {
                egIncrement = 1 << (shift - 1)
            }
            
        case OPL3EnvelopeGeneratorStage.sustain.rawValue, OPL3EnvelopeGeneratorStage.release.rawValue:
            if egOff == 0 && reset == 0 && shift > 0 {
                egIncrement = 1 << (shift - 1)
            }
        default:
            if egOff == 0 && reset == 0 && shift > 0 {
              egIncrement = 1 << (shift - 1)
            }
        }
        
        slot.envelopeGeneratorOutput = UInt16((Int(egRout) + egIncrement) & 0x1FF)
        
        // Key off check
        if reset != 0 {
            slot.envelopeGeneratorState = OPL3EnvelopeGeneratorStage.attack.rawValue
        }
        
        if slot.regKeyState == 0 {
            slot.envelopeGeneratorState = OPL3EnvelopeGeneratorStage.release.rawValue
        }
    }
    
    // MARK: - Key On/Off
    
    /// Turns key on for an operator
    static func envelopeKeyOn(_ slot: OPL3Operator, _ type: OPL3EnvelopeKeyType) {
        slot.regKeyState |= type.rawValue
    }
    
    /// Turns key off for an operator
    static func envelopeKeyOff(_ slot: OPL3Operator, _ type: OPL3EnvelopeKeyType) {
        slot.regKeyState &= ~type.rawValue
    }
}
