//
//  Characters.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 12/01/2024.
//

import Foundation

enum GameVersion {
  case v21 // 2.1 (floppy)
  case v23 // 2.3 (floppy)
  case v24 // 2.4 (floppy)
  case v37 // 3.7 (PC-CD)
  case v38 // 3.8 (PC-CD)
}


struct ResourceFile {
    var flags: UInt16
    var fileName: String
    
    init(_ flags: UInt16, _ fileName: String) {
        self.flags = flags
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


enum GamePhase: UInt8, CaseIterable {
    case dawn = 0
    case day = 1
    case dusk = 2
    case night = 3

    var title: String {
        switch self {
        case .dawn: return "DAWN"
        case .day: return "DAY"
        case .dusk: return "DUSK"
        case .night: return "NIGHT"
        }
    }

    /// The sky of one of the 16 periods of a day. The panel's sun is up in
    /// periods 0-12 and the moon in 11-1 (table at ds:1E7E); the sky
    /// follows: sunrise, day, sunset, night (ScummVM skyPalette; the real
    /// mapping, sub_138B4, is not decoded).
    init(period: Int) {
        switch period & 15 {
        case 0: self = .dawn
        case 1...10: self = .day
        case 11...12: self = .dusk
        default: self = .night
        }
    }

    var lightMode: DuneLightMode {
        switch self {
        case .dawn: return .sunrise
        case .day: return .day
        case .dusk: return .sunset
        case .night: return .night
        }
    }
}


enum TroopOrder: CaseIterable, Equatable {
    case hold
    case advance
    case harvest
    case regroup

    var title: String {
        switch self {
        case .hold: return "HOLD"
        case .advance: return "ADVANCE"
        case .harvest: return "HARVEST"
        case .regroup: return "REGROUP"
        }
    }
}

enum TroopOccupation: CaseIterable, Equatable {
    case none
    case spice
    case army
    case ecology

    var title: String {
        switch self {
        case .none: return "NONE"
        case .spice: return "SPICE"
        case .army: return "ARMY"
        case .ecology: return "ECOLOGY"
        }
    }
}

enum GameplayMilestone: String {
    case meetDuke = "MEET DUKE LETO"
    case findGurney = "FIND GURNEY"
    case firstSietch = "FIRST SIETCH"
    case recruitFremen = "RECRUIT FREMEN"
    case prospectorsFound = "FIND PROSPECTORS"
    case shipmentRequested = "SPICE SHIPMENT"
    case shipmentAccepted = "SHIPMENT ACCEPTED"
}


/// Constants decoded from the DOS executable rather than tuned for the
/// Swift frame loop.  Both the floppy DUNEPRG.EXE and the CD DNCDPRG.EXE
/// contain the same location table and timer constants.
enum OriginalGameData {
    static let pitBaseFrequency: Double = 1_193_182.0
    static let pitDivisor: UInt16 = 0x1745
    static let timerInterruptFrequency = pitBaseFrequency / Double(pitDivisor)

    // The IRQ handler decrements this counter and advances game time after
    // it becomes negative.  Therefore a reload of 0x2EE0 produces 0x2EE1
    // interrupt periods between game-time increments.
    static let gameTimerReload: UInt16 = 0x2EE0
    static let interruptsPerGameTick = Double(gameTimerReload) + 1.0
    static let secondsPerGameTick = interruptsPerGameTick / timerInterruptFrequency

    static let gameHoursPerDay = 16
    static let sunlightDayOffset = 3

    // DUNEPRG.EXE: file offset 0xEFF0.  DNCDPRG.EXE: file offset 0xF7B0.
    // Each record is 0x1C bytes; spice density is byte 0x12.
    static let initialSpiceDensity: [UInt8] = [
        0, 0, 120, 100, 125, 200, 180, 45, 140, 0,
        120, 60, 84, 45, 140, 99, 160, 180, 160, 210,
        0, 200, 170, 240, 200, 240, 180, 160, 100, 250,
        0, 150, 32, 130, 120, 180, 180, 210, 0, 120,
        250, 180, 120, 200, 150, 110, 60, 180, 150, 160,
        170, 210, 195, 240, 200, 210, 50, 0, 230, 200,
        170, 200, 140, 170, 140, 0, 170, 240, 140, 240
    ]

    static func spiceDensity(for location: Int) -> UInt8 {
        guard initialSpiceDensity.indices.contains(location) else { return 0 }
        return initialSpiceDensity[location]
    }
}


/// Small, shared gameplay state used by the interactive Swift slice.
///
/// The original save format stores these values in the data segment
/// (`game_time`, `game_phase`, and per-location spice/troop bytes). Keeping
/// them together here lets the HUD, results view, and scenes observe one
/// state source while the complete save-file reader is still being ported.
final class GameState {
    static let shared = GameState()

    private(set) var elapsedTime: TimeInterval = 0.0
    private(set) var gameTicks: UInt16 = 0
    private(set) var gameHour: Int = 0
    private(set) var sunlightDay: Int = 0
    private(set) var day: Int = 1
    private(set) var phase: GamePhase = .dawn
    private(set) var troopOrder: TroopOrder = .hold
    private(set) var troopOccupation: TroopOccupation = .none
    private(set) var milestone: GameplayMilestone = .meetDuke
    private(set) var lastAction = "ARRIVAL"

    // Story phase values are the phase bytes used by DUNEPRG.EXE/DNCDPRG.EXE.
    // The Swift slice does not evaluate CONDIT.HSQ yet, but keeping the same
    // byte milestones makes the visible branches line up with the original
    // event callbacks and with dune-re's phase table.
    /// ds:2A, owned by the data segment; only dialogue actions, phase
    /// callbacks and discoveries change it (Story.setGamePhase).
    var storyPhase: UInt8 { World.shared.b(World.phase) }
    private(set) var charisma: UInt8 = 0
    private(set) var prospectorFound = false
    private(set) var prospectorLocation = 2 // Carthag-Timin in the original troop table
    private(set) var spiceStock: UInt16 = 0 // stored in 10 kg batches by the DOS game
    private(set) var shipmentDemand: UInt16 = 0
    private(set) var shipmentOfferAmounts: [UInt16] = []
    private(set) var shipmentPending = false
    private(set) var shipmentDaysRemaining: Int = 0
    private(set) var shipmentAgreedAmount: UInt16 = 0
    private(set) var shipmentArmed = false
    private var shipmentArguingCounter: UInt8 = 0
    private var shipmentSequence: UInt8 = 0
    private var randomSeed: UInt16 = 0

    // These are the current location's data-segment fields. They are kept as
    // raw game values until the location table decoder supplies labels and
    // scaling from the original binary.
    private(set) var spiceDensity: UInt8 = 0
    private(set) var currentLocation = 0
    private(set) var travelStep = 0

    // The executable's location table gives us the initial spice byte, but
    // troop counts live in the save/game-state records and are not yet fully
    // decoded. Keep that distinction explicit instead of inventing counts.
    private(set) var locationSpice: [UInt8] = OriginalGameData.initialSpiceDensity
    private(set) var locationTroops: [UInt8] = Array(repeating: 0, count: OriginalGameData.initialSpiceDensity.count)

    private var tickAccumulator: TimeInterval = 0.0

    private init() {}

    func reset() {
        elapsedTime = 0.0
        // ds:2 starts at 2 in both executables (checked in the data segment).
        gameTicks = World.shared.w(World.gameTime)
        gameHour = Int(gameTicks & 0x000F)
        sunlightDay = Int((UInt32(gameTicks) + UInt32(OriginalGameData.sunlightDayOffset)) >> 4)
        day = World.shared.day
        phase = GamePhase(period: gameHour)
        phase = .dawn
        troopOrder = .hold
        troopOccupation = .none
        milestone = .meetDuke
        lastAction = "ARRIVAL"
        charisma = 0
        prospectorFound = false
        prospectorLocation = 2
        spiceStock = 0
        shipmentDemand = 0
        shipmentOfferAmounts = []
        shipmentPending = false
        shipmentDaysRemaining = 0
        shipmentAgreedAmount = 0
        shipmentArmed = false
        shipmentArguingCounter = 0
        shipmentSequence = 0
        // The original seeds this LCG from the BIOS timer.  The algorithm is
        // exact; a fixed seed keeps regression captures deterministic.
        randomSeed = 0x7302
        spiceDensity = OriginalGameData.spiceDensity(for: 0)
        currentLocation = 0
        travelStep = 0
        locationSpice = OriginalGameData.initialSpiceDensity
        locationTroops = Array(repeating: 0, count: OriginalGameData.initialSpiceDensity.count)
        tickAccumulator = 0.0
    }

    /// Travel: one period per 16 cells flown (seg000 flight loop).
    func passPeriods(_ periods: Int) {
        guard periods > 0 else { return }
        advance(OriginalGameData.secondsPerGameTick * Double(periods))
    }


    func advance(_ elapsed: TimeInterval) {
        guard elapsed > 0 else { return }
        elapsedTime += elapsed
        tickAccumulator += elapsed

        let oldDay = day
        while tickAccumulator >= OriginalGameData.secondsPerGameTick {
            tickAccumulator -= OriginalGameData.secondsPerGameTick
            gameTicks &+= 1
            // Each period runs the troops' jobs and the day's events.
            World.shared.setW(World.gameTime, gameTicks)
            World.shared.runPeriod()
        }

        World.shared.setW(World.gameTime, gameTicks)
        gameHour = Int(gameTicks & 0x000F)
        // GetSunlightDay (CS1:1AD1): ((t + 3) >> 4), shown modulo 365, 1-based.
        day = World.shared.day
        sunlightDay = Int((UInt32(gameTicks) + UInt32(OriginalGameData.sunlightDayOffset)) >> 4)

        phase = GamePhase(period: gameHour)

        if day != oldDay {
            if shipmentPending && shipmentDaysRemaining > 0 {
                shipmentDaysRemaining -= 1
            }
            // The Emperor's demands are the data segment's now
            // (World.armShipments / shipmentDay, Shipments.swift).
        }
    }

    func cycleTroopOrder() {
        let orders = TroopOrder.allCases
        guard let index = orders.firstIndex(of: troopOrder) else { return }
        troopOrder = orders[(index + 1) % orders.count]
        lastAction = "ORDER \(troopOrder.title)"
    }

    func setTroopOccupation(_ occupation: TroopOccupation) {
        troopOccupation = occupation
        lastAction = "OCCUPATION \(occupation.title)"
        if occupation == .spice && !prospectorFound {
            // The first spice specialization is the same gameplay gate that
            // exposes the prospector branch in the original phase table.
            findProspectors()
        }
    }

    func setMilestone(_ milestone: GameplayMilestone, action: String) {
        self.milestone = milestone
        lastAction = action
    }

    func advanceStory(to phase: UInt8, action: String) {
        // Kept for the milestone text only: the phase itself now moves
        // through DIALOGUE.HSQ actions 11/12 (Story), as in the original.
        lastAction = action
        if phase >= 0x01 && milestone == .meetDuke {
            milestone = .findGurney
        }
    }

    func findProspectors() {
        prospectorFound = true
        // Phase 5 is what enables FIND PROSPECTORS in the original; it is
        // not set by finding them.
        milestone = .prospectorsFound
        lastAction = "PROSPECTOR AT CARTHAG-TIMIN"
    }

    /// Exact port of dune-re's `spice_shipment_roll_new_demand` formula:
    /// base = sequence * 150 + 100, scaled by (rand_masked(0x3f)+0xe0)/256.
    /// The LCG is the same 16-bit `seed * 0xe56d + 1` generator.
    func rollSpiceShipment() {
        let sequence = UInt32(shipmentSequence)
        shipmentSequence &+= 1
        let base = sequence * 0x96 + 0x64
        let random = UInt32(randMasked(0x3f)) + 0xe0
        var quantity: UInt16
        if base > 0xffff || base * random > 0xffffff {
            quantity = 0xffff
        } else {
            quantity = UInt16((base * random) >> 8)
        }
        shipmentDemand = quantity
        stageDuncanOffers(for: quantity, stock: spiceStock)
        shipmentPending = true
        shipmentDaysRemaining = 4
        shipmentAgreedAmount = 0
        shipmentArmed = false
        shipmentArguingCounter = 0
        milestone = .shipmentRequested
        lastAction = "EMPEROR DEMANDS \(quantity * 10) KGS"
    }

    private func randMasked(_ mask: UInt16) -> UInt16 {
        let product = UInt32(randomSeed) * 0xe56d
        randomSeed = UInt16(truncatingIfNeeded: product).addingReportingOverflow(1).partialValue
        let lo = randomSeed >> 8
        let hi = UInt16((product >> 16) & 0xff)
        return ((hi << 8) | lo) & mask
    }

    func beginDuncanShipmentConversation() {
        if storyPhase < 0x15 {
            lastAction = prospectorFound ? "DUNCAN: INCREASE SPICE PRODUCTION" : "DUNCAN: FIND PROSPECTORS"
            return
        }
        if !shipmentPending {
            rollSpiceShipment()
        }
        milestone = .shipmentRequested
        lastAction = "DUNCAN: REVIEW SHIPMENT"
    }

    func acceptSpiceShipment(option: Int = 0) {
        guard shipmentPending, !shipmentOfferAmounts.isEmpty else { return }
        // The DOS event increments the bargaining counter before ACCEPT and
        // chooses (counter - 1) & 3.  `option` remains as a compatibility
        // escape hatch for scripted tests, but normal play follows the exact
        // conversation counter.
        let selected = option == 0 ? Int(shipmentArguingCounter) & 3 : option & 3
        guard shipmentOfferAmounts.indices.contains(selected) else { return }
        shipmentAgreedAmount = shipmentOfferAmounts[selected]
        shipmentArmed = true
        shipmentArguingCounter &+= 1
        milestone = .shipmentAccepted
        lastAction = "AGREED (shipmentAgreedAmount * 10) KGS; GO TO COMM ROOM"
    }

    /// Port of dune-re's `stage_spice_argue_amounts_with_duncan`. The DOS
    /// routine stages four stock/demand brackets; the later dialogue event
    /// selects one of those entries when Paul accepts the negotiated offer.
    func argueSpiceShipment() {
        guard shipmentPending, !shipmentArmed else { return }
        shipmentArguingCounter &+= 1
        lastAction = "ARGUE SHIPMENT AMOUNTS"
    }

    /// The exact `duncanOffers` bracket from story.cpp/sub_122b1.
    private func stageDuncanOffers(for demand: UInt16, stock: UInt16) {
        let oneAndHalfDemand = demand &+ (demand >> 1)
        let doubleDemand = demand &* 2
        let halfStock = stock >> 1
        let threeQuarterStock = (stock >> 2) &+ halfStock

        if stock < demand {
            shipmentOfferAmounts = [stock, threeQuarterStock, halfStock,
                                    threeQuarterStock &- halfStock]
        } else if stock < oneAndHalfDemand {
            shipmentOfferAmounts = [demand, stock, threeQuarterStock, halfStock]
        } else if stock < doubleDemand {
            shipmentOfferAmounts = [demand, stock, threeQuarterStock,
                                    oneAndHalfDemand]
        } else {
            shipmentOfferAmounts = [demand, stock, oneAndHalfDemand, doubleDemand]
        }
    }

    /// The original does not ship in Duncan's dialogue.  It arms the amount;
    /// the actual subtraction and fulfilment calculation happen in COMM.
    func shipSpiceInCommunicationRoom() {
        guard shipmentArmed else { return }
        let amount = min(shipmentAgreedAmount, spiceStock)
        spiceStock &-= amount
        shipmentPending = false
        shipmentDemand = 0
        shipmentDaysRemaining = 0
        shipmentOfferAmounts = []
        shipmentAgreedAmount = 0
        shipmentArmed = false
        milestone = .shipmentAccepted
        lastAction = "SHIPPED (amount * 10) KGS TO EMPEROR"
    }

    func refuseSpiceShipment() {
        guard shipmentPending else { return }
        lastAction = "SPICE SHIPMENT REFUSED"
    }

    func setLocation(_ location: Int, spiceDensity: UInt8) {
        currentLocation = min(max(0, location), locationSpice.count - 1)
        self.spiceDensity = spiceDensity
        travelStep = 0
    }

    func setLocation(_ location: Int) {
        currentLocation = min(max(0, location), locationSpice.count - 1)
        spiceDensity = locationSpice[currentLocation]
        travelStep = 0
    }

    func recordTravelStep() {
        travelStep &+= 1
    }

    func troopCount(at location: Int? = nil) -> UInt8 {
        let index = min(max(0, location ?? currentLocation), locationTroops.count - 1)
        return locationTroops[index]
    }

}
