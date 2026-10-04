//
//  Flight.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 11/05/2024.
//

import Foundation


/// One piece of the flight view: a DUNES frame at a lateral offset and a depth.
private struct FlightObject {
    var z: Int
    var x: Int
    var sprite: Int
}


final class Flight: DuneNode {
    private var contextBuffer = PixelBuffer(width: 320, height: 152)

    private var dunesSprite: Sprite?
    private var sky: Sky?
    private var dayMode: DuneLightMode = .day

    private var objects: [FlightObject] = []
    private var seed: UInt16 = 1
    private var frameClock: TimeInterval = 0

    /// ds:20E7. Rows meet the sky here.
    private static let horizon = 77
    /// ds:20ED. Ornithopter altitude, in the same units as the depth table.
    private static let altitude = 0x48
    /// New rows appear at this depth.
    private static let farDepth = 40
    /// One landscape frame per 16 ticks.
    private static let frameSeconds = 0.080
    /// Sand under the horizon (3AF8).
    private static let groundColour = 0xBF
    /// ds:20FD. The eight sets of lateral positions a row can take.
    private static let xSets: [[Int]] = [
        [-900, -200, 200, 900], [-1300, -400, 0, 1300], [-800, -100, 400, 800], [-600, -300, 100, 600],
        [-1200, -500, 300, 700], [-1000, -50, 500, 1000], [-700, -150, 50, 800], [-1100, -350, 350, 600]
    ]

    private var groundRect: DuneRect {
        DuneRect(0, Int16(Self.horizon), 320, UInt8(152 - Self.horizon))
    }

    init() {
        super.init("Flight")
    }


    override func onEnable() {
        dunesSprite = Sprite("DUNES.HSQ")
        sky = Sky()
        seed = 1
        frameClock = 0
        fillRows()
    }


    override func onDisable() {
        dunesSprite = nil
        sky = nil
        objects.removeAll()
    }


    override func onParamsChange() {
        if let dayMode = params["dayMode"] {
            self.dayMode = dayMode as! DuneLightMode
        }

        if let durationParam = params["duration"] {
            self.duration = durationParam as! TimeInterval
        }
    }


    override func update(_ elapsedTime: TimeInterval) {
        currentTime += elapsedTime

        if currentTime > duration {
            EventManager.nodeEndedEvent.notify(NodeEventData(self.name))
            return
        }

        frameClock += elapsedTime
        var steps = 0

        while frameClock >= Self.frameSeconds && steps < 40 {
            frameClock -= Self.frameSeconds
            advance()
            steps += 1
        }
    }


    override func render(_ buffer: PixelBuffer) {
        drawBackground(buffer)

        guard let dunesSprite = dunesSprite else {
            return
        }

        // Far rows were appended last, so they are painted first.
        var index = objects.count - 1

        while index >= 0 {
            draw(objects[index], dunesSprite, buffer)
            index -= 1
        }
    }


    /// 256/z in 8.8 fixed point (5A61). The quotient is zero for every z the view uses.
    private static func depthScale(_ z: Int) -> Int {
        let denom = 75 * z
        let quotient = 75 / denom
        let remainder = 75 % denom
        return (quotient << 8) | ((65536 * remainder / denom) >> 8)
    }


    /// The intro has no route map, so each row is open sand: DUNES frames 0-7.
    private func nextSprite() -> Int {
        Int(random() >> 8) & 7
    }


    private func random() -> UInt16 {
        seed = seed &* 0xE56D &+ 1
        return seed
    }


    /// emit_row (5982): four pieces at one depth, from one of the eight x sets.
    private func emitRow(_ z: Int) {
        _ = random()
        let xs = Self.xSets[Int((seed >> 8) & 0x38) >> 3]
        var i = 0

        while i < xs.count {
            objects.append(FlightObject(z: z, x: xs[i], sprite: nextSprite()))
            i += 1
        }
    }


    /// The initial fill (76CA): five groups of eight rows, from the foreground back to z 40.
    private func fillRows() {
        objects.removeAll()
        var group = 0

        while group < 5 {
            var z = 1 + 8 * group
            let end = 9 + 8 * group

            while z < end {
                emitRow(z)
                z += 1
            }

            group += 1
        }
    }


    /// One frame (54ED): every piece steps nearer and drops out at depth 0, then a row enters at z 40.
    private func advance() {
        var index = 0
        var kept = 0

        while index < objects.count {
            let object = objects[index]

            if object.z > 1 {
                objects[kept] = FlightObject(z: object.z - 1, x: object.x, sprite: object.sprite)
                kept += 1
            }

            index += 1
        }

        if kept < objects.count {
            objects.removeLast(objects.count - kept)
        }

        emitRow(Self.farDepth)
    }


    /// project_and_draw (5A8D). The ground line is horizon + altitude * (256/z).
    /// `drawFrame` scales from the top-left, so the anchor is placed on that line by shifting y.
    private func draw(_ object: FlightObject, _ dunes: Sprite, _ buffer: PixelBuffer) {
        let depth = Self.depthScale(object.z)

        guard depth > 0 else {
            return
        }

        let frame = dunes.frame(at: object.sprite)
        let scale = Double(depth) / 256.0
        let baseline = Self.horizon + 256 * Self.altitude * depth / 65536
        let left = 160 + object.x * depth / 256
        let top = baseline - Int(Double(frame.anchor) * scale)

        dunes.drawFrame(
            UInt16(object.sprite),
            x: Int16(clamping: left),
            y: Int16(clamping: top),
            buffer: buffer,
            effect: .transform(scale: scale)
        )
    }


    private func drawBackground(_ buffer: PixelBuffer) {
        if contextBuffer.tag == dayMode.asInt {
            contextBuffer.render(to: buffer, effect: .none)
            return
        }

        guard let sky = sky else {
            return
        }

        sky.lightMode = dayMode
        sky.render(contextBuffer)
        Primitives.fillRect(groundRect, Self.groundColour, contextBuffer, isOffset: false)

        contextBuffer.render(to: buffer, effect: .none)
        contextBuffer.tag = dayMode.asInt
    }
}
