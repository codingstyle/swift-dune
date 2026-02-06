//
//  OPL3SignalSource.swift
//  SwiftDune
//
//  Ported from Nuked OPL3 (Spice86 C# implementation)
//  Original C code: Copyright (C) 2013-2020 Nuke.YKT
//  SPDX-License-Identifier: LGPL-2.1
//
//  Created by Christophe Buguet on 04/02/2026.
//

import Foundation

/// Source kind for signal reading
enum OPL3SignalSourceKind: UInt8 {
    case zero = 0
    case output = 1
    case feedback = 2
}

/// Lightweight indirection used to read either zero, operator output, or operator feedback
/// without allocating closures/delegates.
struct OPL3SignalSource {
    private weak var source: OPL3Operator?
    private let kind: OPL3SignalSourceKind
    
    private init(source: OPL3Operator?, kind: OPL3SignalSourceKind) {
        self.source = source
        self.kind = kind
    }
    
    /// A signal source that always returns zero
    static let zero = OPL3SignalSource(source: nil, kind: .zero)
    
    /// Reads the current signal value based on the source kind
    @inline(__always)
    func read() -> Int16 {
        switch kind {
        case .output:
            return source?.out ?? 0
        case .feedback:
            return source?.feedbackModifiedSignal ?? 0
        case .zero:
            return 0
        }
    }
    
    /// Creates a signal source that reads from operator output
    @inline(__always)
    static func fromOutput(_ source: OPL3Operator) -> OPL3SignalSource {
        return OPL3SignalSource(source: source, kind: .output)
    }
    
    /// Creates a signal source that reads from operator feedback
    @inline(__always)
    static func fromFeedback(_ source: OPL3Operator) -> OPL3SignalSource {
        return OPL3SignalSource(source: source, kind: .feedback)
    }
}
