//
//  Characters.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 12/01/2024.
//

import Foundation


enum DuneLightMode: Equatable {
    case sunrise
    case day
    case sunset
    case night
    case custom(index: Int, prevIndex: Int, blend: CGFloat)
    
    var asInt: UInt32 {
        switch self {
            case .sunrise: return 0
            case .day: return 1
            case .sunset: return 2
            case .night: return 3
            case.custom(_, _, _): return 4
        }
    }
    
    static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.asInt == rhs.asInt
    }
}


enum DuneOrientation: UInt8 {
  case north = 0
  case northEast = 1
  case east = 2
  case southEast = 3
  case south = 4
  case southWest = 5
  case west = 6
  case northWest = 7
}


enum DuneGameVersion {
  case v10 // 1.0 (Amiga)
  case v21 // 2.1 (floppy)
  case v23 // 2.3 (floppy)
  case v24 // 2.4 (floppy)
  case v37 // 3.7 (PC-CD)
  case v38 // 3.8 (PC-CD)
}
