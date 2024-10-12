//
//  Palette.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 26/08/2023.
//

import Foundation
import CoreGraphics
import AppKit

final class Palette {
    private let paletteSize = 256
    private let colorAlignment = MemoryLayout<UInt32>.alignment
    private let colorSize = MemoryLayout<UInt32>.size
    private let paletteByteSize = 256 * MemoryLayout<UInt32>.size

    var stashRawPointer: UnsafeMutablePointer<UInt32>
    var rawPointer: UnsafeMutablePointer<UInt32>
    
    init() {
        rawPointer = UnsafeMutablePointer<UInt32>.allocate(capacity: paletteSize)
        stashRawPointer = UnsafeMutablePointer<UInt32>.allocate(capacity: paletteSize)
        clear()
    }
    
    
    deinit {
        stashRawPointer.deallocate()
        rawPointer.deallocate()
    }
    
    
    func stash() {
        memcpy(stashRawPointer, rawPointer, paletteByteSize)
    }

    func unstash() {
        memcpy(rawPointer, stashRawPointer, paletteByteSize)
    }

    
    func clear() {
        let _ = memset(rawPointer, 0, paletteByteSize)
    }
    
    
    func update(_ chunk: inout Array<UInt32>, start: UInt16, count: UInt16) {
        memcpy(rawPointer + Int(start), &chunk, Int(count) * colorSize)
    }
    
    
    func rgbaColor(at index: Int, to: inout UInt32) {
        memcpy(&to, rawPointer + index, colorSize)
        
        if index == 0 {
            to &= 0x00FFFFFF
        }
    }
    
    
    func color(at index: Int) -> DuneColor {
        let color: UInt32 = rawPointer[index]
        
        return DuneColor(
            UInt8(color & 0xFF),
            UInt8((color >> 8) & 0xFF),
            UInt8((color >> 16) & 0xFF),
            UInt8((color >> 24) & 0xFF)
        )
    }
    
    
    func nsColor(at index: Int) -> NSColor {
        let color: UInt32 = rawPointer[index]

        return NSColor(
            deviceRed: CGFloat(color & 0xFF) / 255.0,
            green: CGFloat((color >> 8) & 0xFF) / 255.0,
            blue: CGFloat((color >> 16) & 0xFF) / 255.0,
            alpha: CGFloat(color >> 24) / 255.0
        )
    }
    
    
    func allColors() -> [NSColor] {
        var i = 0
        var colors: [NSColor] = []
        
        while i < paletteSize {
            let color = nsColor(at: Int(i))
            colors.append(color)
            i += 1
        }
        
        return colors
    }
}


extension NSColor {
    var asHexString: String {
        return "#000000"
        /*
        let r = String.fromByte(UInt8(255.0 * self.redComponent))
        let g = String.fromByte(UInt8(255.0 * self.blueComponent))
        let b = String.fromByte(UInt8(255.0 * self.greenComponent))
        
        return "#\(r)\(g)\(b)"
        */
    }
}
