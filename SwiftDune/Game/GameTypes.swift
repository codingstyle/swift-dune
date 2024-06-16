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

enum DuneLightMode: UInt32 {
    case sunrise = 0
    case day
    case sunset
    case night
}
