//
//  Math.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 01/01/2024.
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
    var x: Int16
    var y: Int16
    
    init(_ x: Int16, _ y: Int16) {
        self.x = x
        self.y = y
    }
    
    mutating func reset() {
        self.x = 0
        self.y = 0
    }
    
    static func + (lhs: DunePoint, rhs: DunePoint) -> DunePoint {
        return DunePoint(lhs.x + rhs.x, lhs.y + rhs.y)
    }
    
    static func += (lhs: inout DunePoint, rhs: DunePoint) -> DunePoint {
        lhs.x += rhs.x
        lhs.y += rhs.y
        return lhs
    }
    
    static func - (lhs: DunePoint, rhs: DunePoint) -> DunePoint {
        return DunePoint(lhs.x - rhs.x, lhs.y - rhs.y)
    }
    
    static func -= (lhs: inout DunePoint, rhs: DunePoint) -> DunePoint {
        lhs.x -= rhs.x
        lhs.y -= rhs.y
        return lhs
    }
    
    static func * (lhs: DunePoint, rhs: Double) -> DunePoint {
        let x: Int = Int(Double(lhs.x) * rhs)
        let y: Int = Int(Double(lhs.y) * rhs)
        
        return DunePoint(Int16(truncatingIfNeeded: x), Int16(truncatingIfNeeded: y))
    }
    
    static func *= (lhs: inout DunePoint, rhs: Double) -> DunePoint {
        lhs.x = Int16(Double(lhs.x) * rhs)
        lhs.y = Int16(Double(lhs.y) * rhs)
        
        return lhs
    }
    
    static func / (lhs: DunePoint, rhs: Double) -> DunePoint {
        return DunePoint(Int16(Double(lhs.x) / rhs), Int16(Double(lhs.y) / rhs))
    }
    
    static func /= (lhs: inout DunePoint, rhs: Double) -> DunePoint {
        lhs.x = Int16(Double(lhs.x) / rhs)
        lhs.y = Int16(Double(lhs.y) / rhs)
        return lhs
    }
    
    static let zero = DunePoint(0, 0)
}


struct DuneRect {
  var x: Int16
  var y: Int16
  var width: UInt16
  var height: UInt8
  
  init(_ x: Int16, _ y: Int16, _ width: UInt16, _ height: UInt8) {
    self.x = x
    self.y = y
    self.width = width
    self.height = height
  }
  
  static let fullScreen = DuneRect(0, 0, 320, 152)
  
  func contains(_ pt: DunePoint) -> Bool {
    return (pt.x >= x) && (pt.x < x + Int16(width)) && (pt.y >= y) && (pt.y < y + Int16(height))
  }
}

struct Math {
    static let PI: Double = 3.141592
    
    @inlinable static func clamp<T: FixedWidthInteger>(_ value: T, _ minValue: T, _ maxValue: T) -> T {
        return min(maxValue, max(minValue, value))
    }
    
    @inlinable static func clampf<T: BinaryFloatingPoint>(_ value: T, _ minValue: T, _ maxValue: T) -> T {
        return min(maxValue, max(minValue, value))
    }
    
    @inlinable static func lerp<T: FixedWidthInteger>(_ a: T, _ b: T, _ value: CGFloat) -> T {
        return T(CGFloat(a) + CGFloat(Int(b) - Int(a)) * value)
    }

    @inlinable static func lerpRect(_ a: DuneRect, _ b: DuneRect, _ value: CGFloat) -> DuneRect {
        let x = Math.lerp(a.x, b.x, value)
        let y = Math.lerp(a.y, b.y, value)
        let w = Math.lerp(a.width, b.width, value)
        let h = Math.lerp(a.height, b.height, value)
        
        return DuneRect(x, y, w, h)
    }

    @inlinable static func lerpf<T: BinaryFloatingPoint>(_ a: T, _ b: T, _ value: CGFloat) -> T {
        return T(CGFloat(a) + CGFloat(b - a) * value)
    }
    
    @inlinable static func random<T: FixedWidthInteger>(_ a: T, _ b: T) -> T {
        return T.random(in: a...b)
    }
}
