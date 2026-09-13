//
//  OPL3Lfo.swift
//  SwiftDune
//
//  Ported from Nuked OPL3 (Spice86 C# implementation)
//  Original C code: Copyright (C) 2013-2020 Nuke.YKT
//  SPDX-License-Identifier: LGPL-2.1
//
//  Created by Christophe Buguet on 04/02/2026.
//

import Foundation

/// LFO (Low Frequency Oscillator) functions for tremolo and vibrato
struct OPL3Lfo {
    
    /// Resets LFO state for the chip
    static func reset(_ chip: OPL3Chip) {
        chip.tremolo = 0
        chip.tremoloPosition = 0
        chip.tremoloShift = 4
        chip.vibratoPosition = 0
        chip.vibratoShift = 1
    }
    
    /// Advances LFO state (called each sample)
    @inline(__always)
    static func advance(_ chip: OPL3Chip) {
        // Tremolo update (every 64 samples)
        if (chip.timer & 0x3F) == 0x3F {
            chip.tremoloPosition += 1

            if chip.tremoloPosition >= 210 { 
                chip.tremoloPosition = 0 
            }
        }
        
        // Calculate tremolo value based on position
        if chip.tremoloPosition < 105 {
            chip.tremolo = chip.tremoloPosition >> chip.tremoloShift
        } else {
            chip.tremolo = (210 - chip.tremoloPosition) >> chip.tremoloShift
        }
        
        // Vibrato update (every 1024 samples)
        if (chip.timer & 0x3FF) == 0x3FF {
            chip.vibratoPosition = (chip.vibratoPosition + 1) & 0x07
        }
    }
    
    /// Configures LFO depth from register value
    static func configureDepth(_ chip: OPL3Chip, _ value: UInt8) {
        chip.tremoloShift = (((value >> 7) ^ 1) << 1) + 2
        chip.vibratoShift = ((value >> 6) & 0x01) ^ 1
    }
}
