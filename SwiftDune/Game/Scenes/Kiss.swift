//
//  Kiss.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 10/02/2024.
//

import Foundation


final class Kiss: DuneNode {
    private var contextBuffer = PixelBuffer(width: 320, height: 152)

    private let desertRect = DuneRect(0, 78, 320, 74)
    private let desertIndexPalette = 63
    
    private let zoomRect = DuneRect(0, 52, 210, 100)
    
    private var currentTime: TimeInterval = 0.0
    private let engine = DuneEngine.shared

    private var kissSprite: Sprite?
    private var dunesSprite: Sprite?
    private var sky: Sky?
    private var duration: TimeInterval = 10.0

    private var transitionIn: TransitionEffect = .none
    private var transitionOut: TransitionEffect = .none
    
    
    init() {
        super.init("Kiss")
    }
    
    
    override func onEnable() {
        kissSprite = Sprite("CHANKISS.HSQ")
        dunesSprite = Sprite("DUNES.HSQ")
        sky = Sky()
    }
    
    
    override func onDisable() {
        kissSprite = nil
        sky = nil
        dunesSprite = nil
        currentTime = 0.0
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
    
    
    override func update(_ elapsedTime: TimeInterval) {
        currentTime += elapsedTime
        
        if currentTime > duration {
            engine.sendEvent(self, .nodeEnded)
        }
    }
    
    
    override func render(_ buffer: PixelBuffer) {
        guard let sky = sky,
              let kissSprite = kissSprite,
              let dunesSprite = dunesSprite else {
            return
        }
        
        let intermediateFrameBuffer = engine.intermediateFrameBuffer
        
        sky.lightMode = .night
        sky.render(intermediateFrameBuffer)
        
        Primitives.fillRect(desertRect, desertIndexPalette, intermediateFrameBuffer)
        
        // TODO: map accurate background once flight animation is reverse-engineered

        dunesSprite.drawFrame(0, x: 62, y: 77, buffer: intermediateFrameBuffer, effect: .transform(scale: 0.1))
        dunesSprite.drawFrame(6, x: 174, y: 77, buffer: intermediateFrameBuffer, effect: .transform(scale: 0.2))
        dunesSprite.drawFrame(7, x: 120, y: 77, buffer: intermediateFrameBuffer, effect: .transform(scale: 0.2))
        dunesSprite.drawFrame(3, x: 19, y: 77, buffer: intermediateFrameBuffer, effect: .transform(scale: 0.15))
        dunesSprite.drawFrame(1, x: 240, y: 77, buffer: intermediateFrameBuffer, effect: .transform(scale: 0.15))
        dunesSprite.drawFrame(2, x: 27, y: 78, buffer: intermediateFrameBuffer, effect: .transform(scale: 0.35))
        dunesSprite.drawFrame(16, x: 280, y: 56, buffer: intermediateFrameBuffer, effect: .transform(scale: 0.4))
        dunesSprite.drawFrame(1, x: 108, y: 74, buffer: intermediateFrameBuffer, effect: .transform(scale: 0.5))
        dunesSprite.drawFrame(4, x: 108, y: 77, buffer: intermediateFrameBuffer)

        kissSprite.setPalette()

        if currentTime < 5.0 {
            intermediateFrameBuffer.render(to: contextBuffer, effect: .none)
            kissSprite.drawFrame(0, x: 78, y: 32, buffer: contextBuffer)
        } else {
            intermediateFrameBuffer.render(to: contextBuffer, effect: .zoom(start: 5.0, duration: 5.0, current: currentTime, from: zoomRect, to: zoomRect))
            kissSprite.drawFrame(1, x: 25, y: 4, buffer: contextBuffer)
        }
        
        engine.palette.stash()
        
        var fx: SpriteEffect {
            if currentTime < 2.0 {
                switch transitionIn {
                case .dissolveIn(let fxDuration):
                    return .dissolveIn(start: 0.0, duration: fxDuration, current: currentTime)
                default:
                    return .none
                }
            }
            
            if currentTime > duration - 2.0 {
                switch transitionOut {
                case .dissolveOut(let fxDuration):
                    return .dissolveOut(end: duration, duration: fxDuration, current: currentTime)
                case .fadeOut(let fxDuration):
                    return .fadeOut(end: duration, duration: fxDuration, current: currentTime)
                default:
                    return .none
                }
            }
            
            return .none
        }
        
        contextBuffer.render(to: buffer, effect: fx)
    }
}
