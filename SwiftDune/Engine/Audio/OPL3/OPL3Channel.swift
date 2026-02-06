//
//  OPL3Channel.swift
//  SwiftDune
//
//  Ported from Nuked OPL3 (Spice86 C# implementation)
//  Original C code: Copyright (C) 2013-2020 Nuke.YKT
//  SPDX-License-Identifier: LGPL-2.1
//
//  Created by Christophe Buguet on 04/02/2026.
//

import Foundation

/// Channel type enumeration
enum OPL3ChannelType: UInt8 {
    case twoOp = 0
    case fourOp = 1
    case fourOpPair = 2
    case drum = 3
}

/// Envelope key type
enum OPL3EnvelopeKeyType: UInt8 {
    case normal = 0x01
    case drum = 0x02
}

/// OPL3 Channel - represents a single FM channel
final class OPL3Channel {
    /// The two operators (slots) for this channel
    var slotz: [OPL3Operator] = [OPL3Operator(), OPL3Operator()]
    
    /// Paired channel for 4-op mode
    weak var pair: OPL3Channel?
    
    /// Back-reference to parent chip
    weak var chip: OPL3Chip?
    
    /// Output signal sources (4 outputs for stereo extension support)
    var out: [OPL3SignalSource] = [.zero, .zero, .zero, .zero]
    
    /// Channel type (2-op, 4-op, 4-op pair, drum)
    var channelType: OPL3ChannelType = .twoOp
    
    /// F-Number (frequency)
    var fNumber: UInt16 = 0
    
    /// Block (octave)
    var block: UInt8 = 0
    
    /// Feedback level
    var feedback: UInt8 = 0
    
    /// Connection (algorithm select bit)
    var connection: UInt8 = 0
    
    /// Algorithm value
    var algorithm: UInt8 = 0
    
    /// Key scale value
    var keyScaleValue: UInt8 = 0
    
    /// Channel A output enable mask
    var cha: UInt16 = 0xFFFF
    
    /// Channel B output enable mask
    var chb: UInt16 = 0xFFFF
    
    /// Channel C output enable mask (OPL3 mode)
    var chc: UInt16 = 0
    
    /// Channel D output enable mask (OPL3 mode)
    var chd: UInt16 = 0
    
    /// Channel number (0-17)
    var channelNumber: UInt8 = 0
    
    /// Previous key-on state for edge detection
    var previousKeyOn: Bool = false
    
    // MARK: - Initialization
    
    init() {}
}
