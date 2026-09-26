//
//  Shipments.swift
//  SwiftDune
//
//  The Emperor's spice shipments and the COMM room's messages.
//  Amounts are in 10 kg batches. Offsets are CD data-segment offsets
//  (World.b/w convert them for the floppy).
//
//  Port of the ScummVM Dune engine's story.cpp (armShipments, shipmentDay,
//  rollDemand, duncanOffers, duncanAccept, duncanClosing, shipSpice,
//  addSighting, viewSighting). The random numbers use SwiftDune's
//  rand_masked, which matches the original (s * 0xE56D + 1).
//

import Foundation


extension World {
    static let demand = 0xBC            // word
    static let fulfilment = 0xBE        // last shipment / demand, 128 = exactly
    static let shipmentFlags = 0xBF     // 0x80 armed, 0x10 demand pending, 0x20 seen, 0x08 short once, 0x40 generous
    static let agreed = 0xC0            // word
    static let finalAttack = 0xC2
    static let shipments = 0xC3         // demands so far
    static let sightings = 0xC8         // message count
    static let unread = 0xC9
    static let daysToShipment = 0xCF
    static let arguing = 0x1A
    static let choice = 0x9F            // ACCEPT 1, REFUSE 2, ARGUE 3
    static let offers = 0xB4            // four words
    static let eventDay = 0x118D        // word: the shipment's day (time >> 4)
    static let unpaid = 0x11BB
    static let shipArmed = 0x1158       // word: 0xFFFF while an agreed amount waits
    static let spentToday = 0x1172
    static let sightingList = 0x1179    // ten words: variant << 8 | person, bit 7 seen

    private var today: UInt16 { w(World.gameTime) >> 4 }

    /// rand_masked (seg000): the original's generator, seed in ds:0.
    func randMasked(_ mask: UInt16) -> UInt16 {
        let seed = w(0x00)
        let product = UInt32(seed) * 0xE56D
        let next = UInt16(truncatingIfNeeded: product) &+ 1
        setW(0x00, next)
        let lo = next >> 8
        let hi = UInt16((product >> 16) & 0xFF)
        return ((hi << 8) | lo) & mask
    }

    /// sub_124d2: how the last shipment measured up, 0 (all) .. 5 (nothing).
    static func fulfilmentClass(_ fulfilment: UInt8) -> Int {
        [1, 0x40, 0x80, 0x90, 0xFF].filter { fulfilment < $0 }.count
    }

    /// sub_12090, at the first vision: the event day is today and the
    /// first demand is made at once. Returns the message to post.
    func armShipments() -> UInt16 {
        setW(World.eventDay, today)
        return rollDemand()
    }

    /// seg000:20d2: the demand grows with each one and with the last shortfall.
    @discardableResult
    func rollDemand() -> UInt16 {
        let count = b(World.shipments)
        setB(World.shipments, count &+ 1)
        var demand: UInt32 = 0xFFFF
        let base = UInt32(count) * 150 + 100
        if base <= 0xFFFF {
            let product = base * (UInt32(randMasked(0x3F)) + 0xE0)
            if product <= 0xFFFFFF {
                demand = product >> 8
                let fulfilment = b(World.fulfilment)
                if fulfilment & 0x80 == 0 {
                    // Below the demand last time: up to twice as much.
                    let scaled = demand * UInt32(0x100 + Int(~(fulfilment << 1)))
                    demand = min(0xFFFF, scaled >> 8)
                }
            }
        }
        setW(World.demand, UInt16(demand))
        setB(World.daysToShipment, 0)
        setB(World.shipmentFlags, b(World.shipmentFlags) | 0x90)
        DuneEngine.shared.logger.log(.info, "Shipments: demand \(demand * 10) kg (demand \(count + 1))")
        return b(World.fulfilment) & 0x80 != 0 ? 0x20B : 0x30B
    }

    /// seg000:20a4, period 3: reminders, the next demand, or the Emperor's
    /// ending. Returns (ending, message to post).
    func shipmentDay() -> (ending: Bool, sighting: UInt16) {
        let flags = b(World.shipmentFlags)
        guard flags & 0x80 != 0 else { return (false, 0) }
        let eventDay = w(World.eventDay)
        if b(World.finalAttack) != 0 {
            if today != eventDay { setB(World.daysToShipment, UInt8(truncatingIfNeeded: eventDay &- today)) }
            return (false, 0)
        }
        if flags & 0x10 != 0 {
            // A demand is pending: reminders on days 1-3 after, then the end.
            let late = today &- eventDay
            if late == 0 { return (false, 0) }
            if late >= 4 { return (true, 0) }
            let reminders: [[UInt16]] = [[4, 5, 6, 0], [5, 6, 0, 0], [6, 0, 0, 0]]
            let reminder = reminders[Int(late) - 1][min(World.fulfilmentClass(b(World.fulfilment)), 2)]
            if reminder == 0 { return (true, 0) }
            return (false, reminder << 8 | 0x0B)
        }
        if b(World.unpaid) != 0 { return (true, 0) }
        if today != eventDay {
            setB(World.daysToShipment, UInt8(truncatingIfNeeded: eventDay &- today))
            return (false, 0)
        }
        return (false, rollDemand())
    }

    /// Period 8: vision 0x30B while a demand waits, Duncan is not with
    /// Paul, Paul is not in the COMM room and the final attack has not begun.
    var shipmentReminderDue: Bool {
        b(World.shipmentFlags) & 0x10 != 0 && w(World.personsWith) & 8 == 0 && b(0x0B) != 8 && b(World.finalAttack) == 0
    }

    /// Duncan's dialogue event 8 (seg000:2239): the four amounts he offers.
    func duncanOffers() {
        setB(World.choice, 0)
        setW(0x20, 0)
        setB(World.arguing, 0)
        let stock = w(World.spiceStock)
        if stock > 0 { setB(World.choice, 3) }
        var flags = b(World.shipmentFlags) & 0xF9
        let demand = w(World.demand)
        let half = demand &+ (demand >> 1), twice = demand &* 2
        let stockHalf = stock >> 1, stockThree = (stock >> 2) &+ (stock >> 1)
        var o: [UInt16]
        if stock < demand {
            o = [stock, stockThree, stockHalf, stockThree &- stockHalf]
        } else if stock < half {
            o = [demand, stock, stockThree, stockHalf]; flags |= 2
        } else if stock < twice {
            o = [demand, stock, stockThree, half]; flags |= 4
        } else {
            o = [demand, stock, half, twice]; flags |= 6
        }
        setB(World.shipmentFlags, flags)
        for i in 0..<4 { setW(World.offers + 2 * i, o[i]) }
        DuneEngine.shared.logger.log(.info, "Shipments: Duncan offers \(o) (demand \(demand), stock \(stock))")
    }

    /// ACCEPT (1), REFUSE (2), ARGUE (3) for Duncan (seg000:241a...).
    func bargainChoice(_ choice: UInt8) {
        setB(World.choice, choice)
        setB(World.arguing, b(World.arguing) &+ 1)
    }

    /// Duncan's event 9 (seg000:24ee): an accepted offer is agreed and armed.
    func duncanAccept() {
        guard b(World.choice) < 2 else { return }
        let index = Int(b(World.arguing) &- 1) & 3
        setW(World.agreed, w(World.offers + 2 * index))
        setW(World.shipArmed, 0xFFFF)
        DuneEngine.shared.logger.log(.info, "Shipments: agreed on \(Int(w(World.agreed)) * 10) kg")
    }

    /// Duncan's event 15 (seg000:24a3): the bargaining is over. Returns the
    /// message to post and whether the talk ends after this line.
    func duncanClosing() -> (sighting: UInt16, endTalk: Bool) {
        if b(World.phase) < 0x10 {
            setRawB(0xFF7, rawB(0xFF7) | 0x10)
            return (0, false)
        }
        setW(World.agreed, 0)
        setB(World.shipmentFlags, b(World.shipmentFlags) | 1)
        let c = World.fulfilmentClass(b(World.fulfilment))
        if c + 7 == 0x0C { setB(World.unpaid, b(World.unpaid) &+ 1) }
        return (UInt16((c + 7) << 8) | 0x0B, true)
    }

    /// The shipment leaves on entering room 8 (COMM) with Duncan there
    /// while an amount is agreed and armed.
    var shipmentReady: Bool {
        placeType == Location.palace && room == 8 && (w(World.agreed) & w(World.shipArmed)) != 0
            && peopleInRoom().contains(World.duncan)
    }

    /// sub_12566 (its star-field animation is not shown).
    func shipSpice() {
        let stock = w(World.spiceStock)
        let amount = min(w(World.agreed), stock)
        setW(World.spiceStock, stock - amount)
        setW(World.spentToday, w(World.spentToday) &+ amount)
        let demand = max(w(World.demand), 1)
        let ratio = min((UInt32(amount) << 8) / UInt32(demand), 0x1FF)
        var fulfilment = UInt8(ratio >> 1)
        if fulfilment == 0 { fulfilment = 1 }
        setB(World.fulfilment, fulfilment)
        var flags: UInt8 = 0x40
        var days: UInt16 = 7
        if fulfilment < 0xC0 {
            days -= 1
            if fulfilment <= 0x80 {
                days -= 1
                flags = 0
                if fulfilment != 0x80 {
                    days -= 1
                    flags = 8
                    if b(World.shipmentFlags) & 8 != 0 { setB(World.fulfilment, 0) } // short twice running
                }
            }
        }
        setB(World.shipmentFlags, flags | 0x80)
        var eventDay = w(World.eventDay) &+ days
        eventDay &+= randMasked(UInt16((b(World.shipments) >> 1) & 3))
        setW(World.eventDay, eventDay)
        setB(World.daysToShipment, UInt8(truncatingIfNeeded: eventDay &- today))
        setW(World.shipArmed, 0)
        DuneEngine.shared.logger.log(.info, "Shipments: shipped \(Int(amount) * 10) kg (\(Int(fulfilment) * 100 / 128)% of the demand), next in \(b(World.daysToShipment)) days")
    }


    // MARK: COMM messages ("sightings")

    var sightingCount: Int { min(Int(b(World.sightings)), 10) }

    func sighting(_ index: Int) -> UInt16 { w(World.sightingList + 2 * index) }

    func addSighting(_ sighting: UInt16) {
        guard sighting != 0 else { return }
        for i in 0..<sightingCount where self.sighting(i) & 0xFF7F == sighting { return }
        if sightingCount >= 10 {
            for i in 0..<9 { setW(World.sightingList + 2 * i, self.sighting(i + 1)) }
            setW(World.sightingList + 18, 0)
            setB(World.sightings, 9)
        }
        setW(World.sightingList + 2 * sightingCount, sighting)
        setB(World.sightings, b(World.sightings) &+ 1)
        setB(World.unread, b(World.unread) &+ 1)
        if b(World.phase) >= 0x38 && b(0x0B) != 8 { queueVision(0x201) }
        DuneEngine.shared.logger.log(.info, "COMM: message from person \(sighting & 0x3F) (variant \(sighting >> 8))")
    }

    /// Reading a message marks it seen (seg000:293e). Returns the sender.
    func viewSighting(_ index: Int) -> (person: Int, variant: UInt8) {
        let s = sighting(index)
        let variant = UInt8(s >> 8), person = Int(s & 0x3F)
        if s & 0x80 == 0 {
            setW(World.sightingList + 2 * index, s | 0x80)
            if b(World.unread) > 0 { setB(World.unread, b(World.unread) - 1) }
            if person == 0x0B && variant &- 2 < 2 { setB(World.shipmentFlags, b(World.shipmentFlags) | 0x20) }
        }
        return (person, variant)
    }
}
