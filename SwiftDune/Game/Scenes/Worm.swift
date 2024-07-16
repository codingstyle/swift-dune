//
//  IntroWorm.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 22/12/2023.
//

import Foundation

final class Worm: DuneNode {
    private var contextBuffer = PixelBuffer(width: 320, height: 152)

    private var wormSprite: Sprite?
    private var skySprite: Sprite?
    
    private var currentTime: TimeInterval = 0.0
    private let engine = DuneEngine.shared
    
    init() {
        super.init("Worm")
    }

    
    override func onEnable() {
        wormSprite = engine.loadSprite("SHAI.HSQ")
        skySprite = engine.loadSprite("SKY.HSQ")
    }
    
    
    override func onDisable() {
        wormSprite = nil
        skySprite = nil
        currentTime = 0.0
    }
    
    
    override func update(_ elapsedTime: TimeInterval) {
        currentTime += elapsedTime
                
        if currentTime > 8.0 {
            DuneEngine.shared.sendEvent(self, .nodeEnded)
        }
    }
    
    
    override func render(_ buffer: PixelBuffer) {
        guard let wormSprite = wormSprite,
              let skySprite = skySprite else {
            return
        }
        
        if contextBuffer.tag != 0x0001 {
            wormSprite.setPalette()
                        
            // Apply sky gradient with blue palette
            skySprite.setAlternatePalette(1)
            
            for x: Int16 in stride(from: 0, to: 320, by: 40) {
                skySprite.drawFrame(0, x: x, y: 0, buffer: contextBuffer)
                skySprite.drawFrame(1, x: x, y: 20, buffer: contextBuffer)
                skySprite.drawFrame(2, x: x, y: 40, buffer: contextBuffer)
                skySprite.drawFrame(3, x: x, y: 60, buffer: contextBuffer)
            }

            wormSprite.setPalette()
            wormSprite.drawFrame(44, x: 0, y: 74, buffer: contextBuffer)
            
            contextBuffer.tag = 0x0001

            engine.palette.stash()
        }

        var fx: SpriteEffect {
            if currentTime < 1.0 {
                return .fadeIn(start: 0.0, duration: 1.0, current: currentTime)
            } else if currentTime > 7.0 {
                return .fadeOut(end: 8.0, duration: 1.0, current: currentTime)
            }
            
            return .none
        }
        
        contextBuffer.render(to: buffer, effect: fx)
    }
}
