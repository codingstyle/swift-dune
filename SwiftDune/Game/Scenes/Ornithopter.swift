//
//  OrnyTakeOff.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 20/02/2024.
//

import Foundation

enum OrnithopterFlightMode: Int {
    case landed = 0
    case takingOff
    case landing
}


final class Ornithopter: DuneNode {
    private var ornySprite: Sprite?

    /// PIT period used by the frame-task wait (0x14 ticks between frames).
    private static let frameInterval: TimeInterval = 20.0 * 0.00499253
    private static let maxFrameSteps = 4

    /// 0x0e is the last rotor frame; later frames retract the gear and climb.
    private static let climbFrame: UInt8 = 0x0e
    /// The takeoff/landing loop stops once the counter reaches 0x21.
    private static let endFrame: UInt8 = 0x21

    private var animFrame: UInt8 = 0
    private var frameStep: Int8 = 0
    private var climbSign: Int16 = 1
    private var tickAccumulator: TimeInterval = 0

    private var flightMode: OrnithopterFlightMode = .landed
    private var locationCode: UInt8 = 0

    init() {
        super.init("Ornithopter")
    }


    override func onEnable() {
        ornySprite = Sprite("ORNYTK.HSQ")
    }


    override func onDisable() {
        ornySprite = nil
        currentTime = 0.0
        flightMode = .landed
        locationCode = 0
        resetAnimation()
    }


    override func onParamsChange() {
        if let flightMode = params["flightMode"] {
            self.flightMode = flightMode as! OrnithopterFlightMode
        }

        if let location = params["location"] {
            locationCode = location as! UInt8
        }

        resetAnimation()
    }


    override func update(_ elapsedTime: Double) {
        currentTime += elapsedTime

        if frameStep == 0 {
            return
        }

        tickAccumulator += elapsedTime
        var steps = 0

        while tickAccumulator >= Self.frameInterval && steps < Self.maxFrameSteps {
            tickAccumulator -= Self.frameInterval
            advanceFrame()
            steps += 1
        }
    }


    override func render(_ buffer: PixelBuffer) {
        guard let ornySprite = ornySprite else {
            return
        }

        let origin = orniOrigin()
        let feetFrame = UInt16(min(max(Int(animFrame) - 0x0f, 0), 5) + 2)
        let wingFrame = UInt16(min(Int(animFrame), 0x0e) + 8)

        ornySprite.setPalette()
        ornySprite.drawFrame(0, x: origin.x, y: origin.y, buffer: buffer)
        ornySprite.drawFrame(1, x: origin.x + 6, y: origin.y + 0x1e, buffer: buffer)
        ornySprite.drawFrame(feetFrame, x: origin.x + 4, y: origin.y + 0x32, buffer: buffer)
        ornySprite.drawFrame(wingFrame, x: origin.x - 0x51, y: origin.y - 3, buffer: buffer)
    }


    /// Pad anchor: (149, 57) for sietches, (202, 73) for palace and city views.
    private func padPosition() -> DunePoint {
        if locationCode >= 0x20 {
            return DunePoint(202, 73)
        }

        return DunePoint(149, 57)
    }


    /// Past the rotor frames the craft climbs: x steps 5 per frame, y drops t²/2.
    private func orniOrigin() -> DunePoint {
        var origin = padPosition()
        let t = Int16(animFrame) - Int16(Self.climbFrame)

        if t > 0 {
            origin.x -= 5 * climbSign * t
            origin.y -= (t * t) >> 1
        }

        return origin
    }


    private func resetAnimation() {
        tickAccumulator = 0

        switch flightMode {
        case .landed:
            animFrame = 0
            frameStep = 0
            climbSign = 1
        case .takingOff:
            animFrame = 0
            frameStep = 1
            climbSign = 1
        case .landing:
            animFrame = 0x1f
            frameStep = -1
            climbSign = -1
        }
    }


    private func advanceFrame() {
        if frameStep == 0 {
            return
        }

        let next = animFrame &+ UInt8(bitPattern: frameStep)

        if next >= Self.endFrame {
            frameStep = 0
            return
        }

        animFrame = next
    }
}
