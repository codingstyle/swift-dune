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


/*
 Original data segment reference from MS-DOS game
 */
@propertyWrapper
struct DuneDataSegment<T> {
  private var value: T
  var offset: UInt16
  
  var wrappedValue: T {
    get { value }
    set { value = newValue }
  }
  
  var projectedValue: DuneDataSegment<T> {
    get { self }
    set { self = newValue }
  }
  
  init(wrappedValue: T, _ offset: UInt16) {
    self.value = wrappedValue
    self.offset = offset
  }
}


protocol DuneDataSegmentValue {
  mutating func write(baseOffset: UInt16, dsOffset: UInt16, value: UInt16, isWord: Bool) -> Bool
}


extension DuneDataSegment where T: FixedWidthInteger {
  init(_ offset: UInt16) {
    self.init(wrappedValue: 0, offset)
  }
}


extension DuneDataSegment where T: RangeReplaceableCollection, T.Element: FixedWidthInteger {
  init(_ offset: UInt16) {
    self.init(wrappedValue: T(), offset)
  }
}


extension DuneDataSegment where T: DuneDataSegmentValue {
  mutating func write(dsOffset: UInt16, value: UInt16, isWord: Bool) -> Bool {
    return wrappedValue.write(baseOffset: offset, dsOffset: dsOffset, value: value, isWord: isWord)
  }
}


extension UInt8: DuneDataSegmentValue {}
extension UInt16: DuneDataSegmentValue {}
extension Int8: DuneDataSegmentValue {}
extension Int16: DuneDataSegmentValue {}


extension DuneDataSegmentValue where Self: FixedWidthInteger {
  mutating func write(baseOffset: UInt16, dsOffset: UInt16, value: UInt16, isWord: Bool) -> Bool {
    if dsOffset != baseOffset {
      return false
    }
    if isWord {
      self = Self(truncatingIfNeeded: value)
    } else {
      self = Self(truncatingIfNeeded: value & 0xFF)
    }
    return true
  }
}


extension Array: DuneDataSegmentValue where Element: FixedWidthInteger {
  mutating func write(baseOffset: UInt16, dsOffset: UInt16, value: UInt16, isWord: Bool) -> Bool {
    let elementSize = MemoryLayout<Element>.size
    if isWord && elementSize != 2 {
      return false
    }
    if !isWord && elementSize != 1 {
      return false
    }
    if dsOffset < baseOffset {
      return false
    }
    
    let relative = Int(dsOffset &- baseOffset)
    if relative % elementSize != 0 {
      return false
    }
    
    let index = relative / elementSize
    if index < 0 || index >= count {
      return false
    }
    
    self[index] = Element(truncatingIfNeeded: value)
    return true
  }
}
