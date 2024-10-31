//
//  Attack.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 08/05/2024.
//

import Foundation

final class Attack: DuneNode {
    private var contextBuffer = PixelBuffer(width: 320, height: 152)
    private var attackSprite: Sprite?
    
    private var transitionIn: TransitionEffect = .none
    private var transitionOut: TransitionEffect = .none
    
    init() {
        super.init("Attack")
    }

    
    override func onEnable() {
        attackSprite = Sprite("ATTACK.HSQ")
    }
    
    
    override func onDisable() {
        attackSprite = nil
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
        guard let attackSprite = attackSprite else {
            return
        }
        
        flash()
        drawBackground(buffer)
        
        // TODO: render projectiles
        
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
    
    
    private func drawBackground(_ buffer: PixelBuffer) {
        guard let attackSprite = attackSprite else {
            return
        }
        
        contextBuffer.clearBuffer()
        
        var x: Int16 = 0
        
        while x < 320 {
            attackSprite.drawFrame(2, x: x, y: 0, buffer: contextBuffer)
            attackSprite.drawFrame(3, x: x, y: 81, buffer: contextBuffer)
            x += 40
        }

        attackSprite.drawFrame(49, x: 0, y: 76, buffer: contextBuffer)
        attackSprite.drawFrame(1, x: 0, y: 134, buffer: contextBuffer)
    }
  
  
    private func flash() {
        var i = 0
      
        while i < 24 {
            //engine.palette.rawPointer[132 + i] = Effects.brighten(
            i += 1
        }
    }
}
