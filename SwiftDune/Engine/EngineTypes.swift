//
//  EngineTypes.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 14/01/2024.
//

import Foundation


protocol DuneNumeric {
    static func + (lhs: Self, rhs: Self) -> Self
    static func += (lhs: inout Self, rhs: Self) -> Self
    
    static func - (lhs: Self, rhs: Self) -> Self
    static func -= (lhs: inout Self, rhs: Self) -> Self

    static func * (lhs: Self, rhs: Double) -> Self
    static func *= (lhs: inout Self, rhs: Double) -> Self

    static func / (lhs: Self, rhs: Double) -> Self
    static func /= (lhs: inout Self, rhs: Double) -> Self
}


struct DunePoint: DuneNumeric {
    let x: Int16
    let y: Int16
    
    init(_ x: Int16, _ y: Int16) {
        self.x = x
        self.y = y
    }
    
    static func + (lhs: DunePoint, rhs: DunePoint) -> DunePoint {
        return DunePoint(lhs.x + rhs.x, lhs.y + rhs.y)
    }

    static func += (lhs: inout DunePoint, rhs: DunePoint) -> DunePoint {
        return DunePoint(lhs.x + rhs.x, lhs.y + rhs.y)
    }
    
    static func - (lhs: DunePoint, rhs: DunePoint) -> DunePoint {
        return DunePoint(lhs.x - rhs.x, lhs.y - rhs.y)
    }

    static func -= (lhs: inout DunePoint, rhs: DunePoint) -> DunePoint {
        return DunePoint(lhs.x - rhs.x, lhs.y - rhs.y)
    }

    static func * (lhs: DunePoint, rhs: Double) -> DunePoint {
        return DunePoint(Int16(Double(lhs.x) * rhs), Int16(Double(lhs.y) * rhs))
    }

    static func *= (lhs: inout DunePoint, rhs: Double) -> DunePoint {
        return DunePoint(Int16(Double(lhs.x) * rhs), Int16(Double(lhs.y) * rhs))
    }

    static func / (lhs: DunePoint, rhs: Double) -> DunePoint {
        return DunePoint(Int16(Double(lhs.x) / rhs), Int16(Double(lhs.y) / rhs))
    }

    static func /= (lhs: inout DunePoint, rhs: Double) -> DunePoint {
        return DunePoint(Int16(Double(lhs.x) / rhs), Int16(Double(lhs.y) / rhs))
    }


    static let zero = DunePoint(0, 0)
}


struct DuneRect {
    let x: Int16
    let y: Int16
    let width: UInt16
    let height: UInt8
    
    init(_ x: Int16, _ y: Int16, _ width: UInt16, _ height: UInt8) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
    
    static let fullScreen = DuneRect(0, 0, 320, 152)
    
    func contains(_ pt: DunePoint) -> Bool {
        return pt.x >= x && pt.x < x + Int16(width) && pt.y >= y && pt.y < y + Int16(height)
    }
}


struct DuneColor {
    let r: UInt8
    let g: UInt8
    let b: UInt8
    let a: UInt8
    
    init(_ r: UInt8, _ g: UInt8, _ b: UInt8, _ a: UInt8 = 0xFF) {
        self.r = r
        self.g = g
        self.b = b
        self.a = a
    }
    
    init(_ rgb: UInt32) {
        self.r = UInt8((rgb & 0xFF0000) >> 16)
        self.g = UInt8((rgb & 0x00FF00) >> 8)
        self.b = UInt8(rgb & 0x0000FF)
        self.a = 0xFF
    }
    
    static let white = DuneColor(0xFFFFFF)
    static let black = DuneColor(0x000000)
    static let red = DuneColor(0xFF0000)
    
    var asARGB: UInt32 {
        return (UInt32(a) << 24) | (UInt32(b) << 16) | (UInt32(g) << 8) | UInt32(r)
    }
}


enum DuneEvent {
    case nodeEnded
    case uiMenuChanged(items: [UInt16])
}

protocol DuneEventObserver: AnyObject {
    func onEvent(_ source: String, _ e: DuneEvent)
}
