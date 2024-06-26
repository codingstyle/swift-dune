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
    
    var rawPointer: UnsafeMutablePointer<UInt32>
    
    init() {
        rawPointer = UnsafeMutablePointer<UInt32>.allocate(capacity: paletteSize)
        clear()
    }
    
    deinit {
        rawPointer.deallocate()
    }
    
    func clear() {
        let _ = memset(rawPointer, 0, paletteSize * colorSize)
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
    
    
    func cgColor(at index: Int) -> CGColor {
        let color: UInt32 = rawPointer[index]
        
        return CGColor(
            red: CGFloat(color & 0xFF) / 255.0,
            green: CGFloat((color >> 8) & 0xFF) / 255.0,
            blue: CGFloat((color >> 16) & 0xFF) / 255.0,
            alpha: CGFloat(color >> 24) / 255.0
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
