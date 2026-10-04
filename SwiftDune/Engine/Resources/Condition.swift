//
//  Conditions.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 13/09/2026.
//

enum ConditionOp: UInt16, CustomDebugStringConvertible {
  case equals = 0x00
  case lessThan = 0x02
  case greaterThan = 0x04
  case notEqual = 0x06
  case lessOrEqual = 0x08
  case greaterOrEqual = 0x0A
  case add = 0x0C
  case sub = 0x0E
  case and = 0x10
  case or = 0x12
  
  func apply(_ a: UInt16, _ b: UInt16) -> UInt16 {
    switch self {
      case .equals:
        return (a == b) ? 1 : 0
      case .lessThan:
        return (a < b) ? 1 : 0
      case .greaterThan:
        return (a > b) ? 1 : 0
      case .notEqual:
        return (a != b) ? 1 : 0
      case .lessOrEqual:
        return (a <= b) ? 1 : 0
      case .greaterOrEqual:
        return (a >= b) ? 1 : 0
      case .add:
        return (a + b)
      case .sub:
        return (a - b)
      case .and:
        return (a & b)
      case .or:
        return (a | b)
    }
  }
  
  var debugDescription: String {
    switch self {
      case .equals: "=="
      case .lessThan: "<"
      case .greaterThan: ">"
      case .notEqual: "!="
      case .lessOrEqual: "<="
      case .greaterOrEqual: ">="
      case .add: "+"
      case .sub: "-"
      case .and: "&"
      case .or: "|"
    }
  }
}


enum ConditionOperand: CustomDebugStringConvertible {
  case variable(isWord: Bool, dsOffset: UInt8)
  case immediate8(UInt8)
  case immediate16(UInt16)
  
  var debugDescription: String {
    switch self {
      case .variable(let isWord, let dsOffset):
        return "\(isWord ? "u16" : "u8")@\(String(format: (isWord ? "%02X" : "%04X"), dsOffset))"
      case .immediate8(let value):
        return "\(String(format: "%02X", value))"
      case .immediate16(let value):
        return "\(String(format: "%04X", value))"
    }
  }
}


struct ConditionOperator: CustomDebugStringConvertible {
  let rawValue: UInt8
  
  var kind: UInt8 {
    return rawValue & 0x1F
  }
  
  var isLoose: Bool {
    return (rawValue & 0x80) != 0
  }
  
  var op: ConditionOp? {
    return ConditionOp(rawValue: UInt16(kind))
  }
  
  var debugDescription: String {
    let symbol = op?.debugDescription ?? String(format: "?%#04x", kind)
    if isLoose {
      return "\(symbol)."
    }
    return symbol
  }
}


enum ConditionToken {
  case operand(ConditionOperand)
  case operation(ConditionOperator)
}


struct ConditionExpression: CustomDebugStringConvertible {
  var tokens: [ConditionToken]
  
  var debugDescription: String {
    var str = ""
    var i = 0
    
    while i < tokens.count {
      switch tokens[i] {
        case .operation(let op):
          str.append(" \(op.debugDescription)")
        case .operand(let operand):
          str.append(" \(operand.debugDescription)")
      }
      i += 1
    }
    
    return str
  }
}


final class Condition {
  private var resource: Resource
  private(set) var expressions: [ConditionExpression] = []
    
  init() {
    self.resource = Resource("CONDIT.HSQ")
    parse()
  }

  
  func parse() {
    guard let stream = resource.stream else {
      Logger.shared.log(.error, "CONDIT.HSQ: stream not available.")
      return
    }
    
    stream.seek(0)
    
    let firstOffset = stream.readUInt16LE()
    let count = Int(firstOffset / 2)
    
    var offsets = [UInt16]()
    offsets.reserveCapacity(count)
    
    stream.seek(0)
    var i = 0
    
    while i < count {
      offsets.append(stream.readUInt16LE())
      i += 1
    }
    
    expressions.removeAll(keepingCapacity: false)
    expressions.reserveCapacity(count)
    
    i = 0
    while i < count {
      let start = UInt32(offsets[i])
      let end: UInt32
      if i < count - 1 {
        end = UInt32(offsets[i + 1])
      } else {
        end = stream.size
      }
      
      expressions.append(parseExpression(stream, start: start, end: end))
      i += 1
    }
    
    Logger.shared.log(.debug, "Added \(expressions.count) condition expressions.")
  }
  
  
  private func parseExpression(_ stream: ResourceStream, start: UInt32, end: UInt32) -> ConditionExpression {
    stream.seek(start)
    
    var tokens = [ConditionToken]()
    
    if stream.offset >= end {
      return ConditionExpression(tokens: tokens)
    }
    
    tokens.append(.operand(parseOperand(stream)))
    
    while stream.offset < end {
      let opcode = stream.readByte()
      
      if opcode == 0xFF {
        break
      }
      
      tokens.append(.operation(ConditionOperator(rawValue: opcode)))
      
      if stream.offset >= end {
        break
      }
      
      tokens.append(.operand(parseOperand(stream)))
    }
    
    return ConditionExpression(tokens: tokens)
  }
  
  
  private func parseOperand(_ stream: ResourceStream) -> ConditionOperand {
    let typeByte = stream.readByte()
    
    if typeByte < 0x80 {
      let dsOffset = stream.readByte()
      return .variable(isWord: typeByte != 1, dsOffset: dsOffset)
    }
    
    if typeByte == 0x80 {
      return .immediate8(stream.readByte())
    }
    
    return .immediate16(stream.readUInt16LE())
  }
}
