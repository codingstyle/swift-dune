//
//  Baron.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 17/01/2024.
//

import Foundation

final class Baron: DuneNode {
    private var contextBuffer = PixelBuffer(width: 320, height: 152)
    
    private var baronSprite: Sprite?
    private var backgroundSprite: Sprite?
    private var sardaukarAnimation: DuneAnimation<Int16>?
    
    private var duration: TimeInterval = 3.0
    private var showSardaukar: Bool = false
    private var transitionIn: TransitionEffect = .none
    private var transitionOut: TransitionEffect = .none
    
    private var currentTime: TimeInterval = 0.0
    private let engine = DuneEngine.shared

    init() {
        super.init("Baron")
    }
    
    
    override func onEnable() {
        baronSprite = engine.loadSprite("BARO.HSQ")
        backgroundSprite = engine.loadSprite("BACK.HSQ")
        sardaukarAnimation = DuneAnimation(
            from: Int16(-150),
            to: Int16(0),
            startTime: 2.0,
            endTime: 2.2
        )
    }
    
    
    override func onDisable() {
        baronSprite = nil
        backgroundSprite = nil
        sardaukarAnimation = nil
        currentTime = 0.0
        duration = 3.0
        showSardaukar = false
        transitionIn = .none
        transitionOut = .none
    }
    
    
    override func onParamsChange() {
        if let durationParam = params["duration"] {
            self.duration = durationParam as! TimeInterval
        }
        
        if let sardaukarParam = params["sardaukar"] {
            self.showSardaukar = sardaukarParam as! Bool
        }
        
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
        guard let baronSprite = baronSprite else {
            return
        }
        
        drawBackground(buffer: contextBuffer)
        
        baronSprite.setPalette()
        baronSprite.drawAnimation(0, buffer: contextBuffer, time: currentTime, offset: DunePoint(83, 0))
        
        if showSardaukar {
            drawAnimatedSardaukars(buffer: contextBuffer, time: currentTime)
        }
        
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
                default:
                    return .none
                }
            }
            
            return .none
        }
        
        contextBuffer.render(to: buffer, effect: fx)
    }
    
    
    private func drawBackground(buffer: PixelBuffer) {
        guard let backgroundSprite = backgroundSprite else {
            return
        }
        
        backgroundSprite.setPalette()
        backgroundSprite.drawFrame(4, x: 0, y: 0, buffer: buffer, effect: .transform(flipX: true, flipY: false))
        backgroundSprite.drawFrame(4, x: 236, y: 0, buffer: buffer)
        backgroundSprite.drawFrame(3, x: 84, y: 0, buffer: buffer)
    }
    
    
    private func drawAnimatedSardaukars(buffer: PixelBuffer, time: Double) {
        guard let backgroundSprite = backgroundSprite,
              let sardaukarAnimation = sardaukarAnimation else {
            return
        }
        
        let x = sardaukarAnimation.interpolate(time)
        
        backgroundSprite.drawFrame(5, x: x, y: 13, buffer: buffer)
        backgroundSprite.drawFrame(6, x: x, y: 13, buffer: buffer)
    }
}
