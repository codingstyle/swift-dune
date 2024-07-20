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
    private let engine = DuneEngine.shared
    private var contextBuffer = PixelBuffer(width: 320, height: 152)
    
    private let desertRect = DuneRect(0, 78, 320, 74)
    private let desertPaletteIndex = 63

    private var ornySprite: Sprite?
    private var skySprite: Sprite?
    private var scenery: Scenery?
    private var sky: Sky?
    
    private var currentTime: TimeInterval = 0.0
    private var duration: TimeInterval = 6.6
    
    private var feetFrameIndex: UInt16 = 2
    private var wingFrameIndex: UInt16 = 8
    private var animationStartTime: TimeInterval = 0.0
    
    private var transitionIn: TransitionEffect = .none
    private var transitionOut: TransitionEffect = .none
    
    private var ornyPosition = DunePoint(68, 56)
    private var takeOffAnimation = DuneAnimation<DunePoint>(
        from: DunePoint(0, 0),
        to: DunePoint(100, 152),
        startTime: 4.0,
        endTime: 5.0,
        timing: .easeIn
    )
    private var feetAnimation = DuneAnimation<UInt16>(from: 2, to: 7, startTime: 4.0, endTime: 4.6)
    private var wingAnimation = DuneAnimation<UInt16>(from: 8, to: 22, startTime: 2.2, endTime: 4.0)
    
    init() {
        super.init("Ornithopter")
    }
    
    
    override func onEnable() {
        ornySprite = Sprite("ORNYTK.HSQ")
        scenery = Scenery("SIET.SAL")
        sky = Sky()
    }
    
    
    override func onDisable() {
        ornySprite = nil
        scenery = nil
        skySprite = nil
        sky = nil
        
        currentTime = 0.0
        ornyPosition = DunePoint(68, 56)
        feetFrameIndex = feetAnimation.startValue
        wingFrameIndex = wingAnimation.startValue
        transitionIn = .none
        transitionOut = .none
    }
    
    
    
    override func onParamsChange() {
        if let transitionInParam = params["transitionIn"] {
            self.transitionIn = transitionInParam as! TransitionEffect
        }

        if let transitionOutParam = params["transitionOut"] {
            self.transitionOut = transitionOutParam as! TransitionEffect
        }
    }
    
    
    override func update(_ elapsedTime: Double) {
        currentTime += elapsedTime

        if currentTime > duration {
            engine.sendEvent(self, .nodeEnded)
            return
        }

        wingFrameIndex = wingAnimation.interpolate(currentTime)
        feetFrameIndex = feetAnimation.interpolate(currentTime)
        ornyPosition = DunePoint(68, 56) - takeOffAnimation.interpolate(currentTime)
    }
    
    
    override func render(_ buffer: PixelBuffer) {
        drawBackground()
        drawOrnithopter()
        
        engine.palette.stash()
        
        var fx: SpriteEffect {
            if currentTime < 2.0 {
                switch transitionIn {
                case .fadeIn(let fxDuration):
                    return .fadeIn(start: 0.0, duration: fxDuration, current: currentTime)
                default:
                    return .none
                }
            }
            
            if currentTime > duration - 2.0 {
                switch transitionOut {
                case .dissolveOut(let fxDuration):
                    return .dissolveOut(end: duration, duration: fxDuration, current: currentTime)
                default:
                    return .none
                }
            }
            
            return .none
        }
        
        contextBuffer.render(to: buffer, effect: fx)
    }

    
    private func drawBackground() {
        guard let scenery = scenery,
              let sky = sky else {
            return
        }
        
        sky.lightMode = .night
        sky.render(contextBuffer)

        Primitives.fillRect(desertRect, desertPaletteIndex, contextBuffer)

        scenery.drawRoom(0, buffer: contextBuffer)
    }
    
    
    private func drawOrnithopter() {
        guard let ornySprite = ornySprite else {
            return
        }
        
        ornySprite.setPalette()
        ornySprite.drawFrame(1, x: ornyPosition.x + 87, y: ornyPosition.y + 33, buffer: contextBuffer)
        ornySprite.drawFrame(0, x: ornyPosition.x + 81, y: ornyPosition.y + 3, buffer: contextBuffer)
        ornySprite.drawFrame(feetFrameIndex, x: ornyPosition.x + 85, y: ornyPosition.y + 53, buffer: contextBuffer)
        ornySprite.drawFrame(wingFrameIndex, x: ornyPosition.x, y: ornyPosition.y, buffer: contextBuffer)
    }
}
