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


struct ResourceFile {
    var id: UInt16
    var fileName: String
    
    init(_ id: UInt16, _ fileName: String) {
        self.id = id
        self.fileName = fileName
    }
}


/* Original resource IDs referenced in DUNEPRG.EXE (v2.1) */
let resourceFiles: [ResourceFile] = [
    ResourceFile(0x0000, "TABLAT.BIN"),
    ResourceFile(0x0000, "DUNECHAR.HSQ"),
    ResourceFile(0x0000, "CONDIT.HSQ"),
    ResourceFile(0x0000, "DIALOGUE.HSQ"),
    ResourceFile(0x0000, "VERBIN.HSQ"),
    ResourceFile(0x0000, "SIET.SAL"),
    ResourceFile(0x0000, "PALACE.SAL"),
    ResourceFile(0x0000, "VILG.SAL"),
    ResourceFile(0x0000, "HARK.SAL"),
    ResourceFile(0x0000, "GLOBDATA.HSQ"),
    ResourceFile(0x0000, "SHAI2.HSQ"),
    ResourceFile(0x0000, "PHRASE11.HSQ"),
    ResourceFile(0x0000, "PHRASE12.HSQ"),
    ResourceFile(0x0100, "DUNEVGA.HSQ"),
    ResourceFile(0x0100, "DUNE386.HSQ"),
    ResourceFile(0x0100, "DUNEPCS.HSQ"),
    ResourceFile(0x0100, "DUNEADL.HSQ"),
    ResourceFile(0x0100, "DUNEAGD.HSQ"),
    ResourceFile(0x0100, "DUNESDB.HSQ"),
    ResourceFile(0x0100, "DUNEMID.HSQ"),
    ResourceFile(0x0100, "COMMAND1.HSQ"),
    ResourceFile(0x0100, "MAP.HSQ"),
    ResourceFile(0x050D, "ICONES.HSQ"),
    ResourceFile(0x3B04, "FRESK.HSQ"),
    ResourceFile(0xD703, "LETO.HSQ"),
    ResourceFile(0x1806, "JESS.HSQ"),
    ResourceFile(0xD905, "HAWA.HSQ"),
    ResourceFile(0x8B03, "IDAH.HSQ"),
    ResourceFile(0x1B05, "GURN.HSQ"),
    ResourceFile(0x8C05, "STIL.HSQ"),
    ResourceFile(0xAD09, "KYNE.HSQ"),
    ResourceFile(0xAB04, "CHAN.HSQ"),
    ResourceFile(0x3D06, "HARA.HSQ"),
    ResourceFile(0x4206, "BARO.HSQ"),
    ResourceFile(0x2708, "FEYD.HSQ"),
    ResourceFile(0x8D08, "EMPR.HSQ"),
    ResourceFile(0x5206, "HARK.HSQ"),
    ResourceFile(0xFF04, "SMUG.HSQ"),
    ResourceFile(0x240C, "FRM1.HSQ"),
    ResourceFile(0x730C, "FRM2.HSQ"),
    ResourceFile(0xDB09, "FRM3.HSQ"),
    ResourceFile(0x6307, "POR.HSQ"),
    ResourceFile(0x9B03, "PROUGE.HSQ"),
    ResourceFile(0x3204, "COMM.HSQ"),
    ResourceFile(0x8302, "EQUI.HSQ"),
    ResourceFile(0x4C06, "BALCON.HSQ"),
    ResourceFile(0x1B04, "CORR.HSQ"),
    ResourceFile(0x7501, "SIET0.HSQ"),
    ResourceFile(0x020A, "SIET1.HSQ"),
    ResourceFile(0xD509, "VILG.HSQ"),
    ResourceFile(0x7608, "FORT.HSQ"),
    ResourceFile(0xA205, "BUNK.HSQ"),
    ResourceFile(0xD005, "FINAL.HSQ"),
    ResourceFile(0x7106, "SERRE.HSQ"),
    ResourceFile(0xD405, "BOTA.HSQ"),
    ResourceFile(0x7400, "PALPLAN.HSQ"),
    ResourceFile(0x4F02, "SUN.HSQ"),
    ResourceFile(0x7807, "VIS.HSQ"),
    ResourceFile(0x550C, "DUNES.HSQ"),
    ResourceFile(0xA905, "ONMAP.HSQ"),
    ResourceFile(0x6805, "PERS.HSQ"),
    ResourceFile(0x2201, "CHANKISS.HSQ"),
    ResourceFile(0x0703, "SKY.HSQ"),
    ResourceFile(0xC901, "ORNYPAN.HSQ"),
    ResourceFile(0x6604, "ORNYTK.HSQ"),
    ResourceFile(0x7902, "ATTACK.HSQ"),
    ResourceFile(0x120E, "STARS.HSQ"),
    ResourceFile(0x3506, "INTDS.HSQ"),
    ResourceFile(0x5407, "SUNRS.HSQ"),
    ResourceFile(0xA004, "PAUL.HSQ"),
    ResourceFile(0xBB0B, "BACK.HSQ"),
    ResourceFile(0xB002, "MOIS.HSQ"),
    ResourceFile(0x2C09, "BOOK.HSQ"),
    ResourceFile(0xF700, "ORNY.HSQ"),
    ResourceFile(0x3A01, "ORNYCAB.HSQ"),
    ResourceFile(0xD201, "GENERIC.HSQ"),
    ResourceFile(0x3803, "CRYO.HSQ"),
    ResourceFile(0x570E, "SHAI.HSQ"),
    ResourceFile(0xDB06, "CREDITS.HSQ"),
    ResourceFile(0x8501, "VER.HSQ"),
    ResourceFile(0x620C, "MAP2.HSQ"),
    ResourceFile(0x850E, "DEATH1.HSQ"),
    ResourceFile(0x640D, "DEATH2.HSQ"),
    ResourceFile(0x780E, "DEATH3.HSQ"),
    ResourceFile(0x0C05, "MIRROR.HSQ"),
    ResourceFile(0xB907, "DUNES2.HSQ"),
    ResourceFile(0x1C0B, "DUNES3.HSQ")
]


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


