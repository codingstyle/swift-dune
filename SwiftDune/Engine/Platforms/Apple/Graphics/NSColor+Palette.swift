//
//  Palette.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 11/10/2026.
//

import AppKit

extension Palette {
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
