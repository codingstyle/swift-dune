//
//  Math.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 01/01/2024.
//

import Foundation

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
