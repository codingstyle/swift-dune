//
//  Attack.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 08/05/2024.
//

import Foundation

struct AttackParticle {
  var spriteId: UInt16
  var velocity: DunePoint
  var flags: UInt8
}


final class Attack: DuneNode {
    private var contextBuffer = PixelBuffer(width: 320, height: 152)
    private var attackSprite: Sprite?
    
    private var transitionIn: TransitionEffect = .none
    private var transitionOut: TransitionEffect = .none
  
    private var maskedRandomSeed: UInt16 = 0x01d2
    private var randomSeed: UInt16 = 0x0273
    private var randomBits: UInt16 = 0x7302
  
    private let initialParticlePositions: [DunePoint] = [
      DunePoint(125, 101),
      DunePoint(100, 101),
      DunePoint(239, 122),
      DunePoint(271, 125)
    ]
  
    private let initialParticleVelocities: [DunePoint] = [
      DunePoint(-6, 4),
      DunePoint(-4, 6),
      DunePoint(-4, -6),
      DunePoint(-6, -4)
    ]
    
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
        maskedRandomSeed = 0x01d2
        randomSeed = 0x0273
        randomBits = 0x7302
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
            EventManager.nodeEndedEvent.notify(NodeEventData(self.name))
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
  
  
    private func maskedRandomNumber(_ mask: UInt16) -> UInt16 {
      let lcgPrime: UInt32 = 0x0E56D
      let product = (UInt32(self.randomSeed) * lcgPrime) + 1
      self.randomSeed = UInt16(product & 0xFF)
      
      return UInt16(product >> 8) & mask
    }
  
  
    private func randomNumber() -> UInt16 {
      let lcgPrime: UInt32 = 0xCBD1
      let product = (UInt32(self.maskedRandomSeed) * lcgPrime) + 1
      self.maskedRandomSeed = UInt16(product & 0xFF)
      
      return UInt16(product >> 8)
    }
  
  
    private func flash() {
        var i = 0
      
        while i < 24 {
            //engine.palette.rawPointer[132 + i] = Effects.brighten(
            i += 1
        }
    }
}
