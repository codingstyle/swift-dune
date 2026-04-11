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
///
/// `source` is stored as `Unmanaged<OPL3Operator>?` — a raw pointer with no ARC — so that
/// `read()` never touches the ARC side-table. The chip owns all slots, so the pointed-to
/// object is always alive while any signal source referencing it is in use.
struct OPL3SignalSource {
    private let source: Unmanaged<OPL3Operator>?
    private let kind: OPL3SignalSourceKind

    /// A signal source that always returns zero
    static let zero = OPL3SignalSource(source: nil, kind: .zero)

    /// Reads the current signal value based on the source kind.
    /// Uses `takeUnretainedValue()` to load the object pointer without any ARC operation.
    @inline(__always)
    func read() -> Int16 {
        guard kind != .zero, let src = source else { return 0 }
        let slot = src.takeUnretainedValue()
        return kind == .output ? slot.out : slot.feedbackModifiedSignal
    }

    /// Creates a signal source that reads from operator output
    @inline(__always)
    static func fromOutput(_ source: OPL3Operator) -> OPL3SignalSource {
        return OPL3SignalSource(source: Unmanaged.passUnretained(source), kind: .output)
    }

    /// Creates a signal source that reads from operator feedback
    @inline(__always)
    static func fromFeedback(_ source: OPL3Operator) -> OPL3SignalSource {
        return OPL3SignalSource(source: Unmanaged.passUnretained(source), kind: .feedback)
    }
}
