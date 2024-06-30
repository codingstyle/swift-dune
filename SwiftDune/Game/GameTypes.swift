//
//  Characters.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 12/01/2024.
//

import Foundation

enum DuneCharacter: String {
    case none = ""
    case leto = "LETO.HSQ"
    case jessica = "JESS.HSQ"
    case paul = "PAUL.HSQ"
    case chani = "CHAN.HSQ"
    case harah = "HARA.HSQ"
    case stilgar = "STIL.HSQ"
    case liet = "LIET.HSQ"
    case baron = "BARO.HSQ"
    case feyd = "FEYD.HSQ"
    case fremen1 = "FRM1.HSQ"
    case fremen2 = "FRM2.HSQ"
    case fremen3 = "FRM3.HSQ"
    case smuggler = "SMUG.HSQ"
}

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
