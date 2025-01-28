//
//  EngineTypes.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 14/01/2024.
//

import Foundation


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
