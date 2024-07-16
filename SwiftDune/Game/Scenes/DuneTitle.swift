//
//  DuneTitle.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 10/12/2023.
//

import Foundation

final class DuneTitle: DuneNode {
    private var contextBuffer = PixelBuffer(width: 320, height: 152)

    private var skySprite: Sprite?
    private var titleSprite: Sprite?
    
    private var currentTime: TimeInterval = 0.0
    private let engine = DuneEngine.shared
    
    private var scrollAnimation: DuneAnimation<Int16>?
    
    init() {
        super.init("DuneTitle")
    }
    
    
    override func onEnable() {
        self.titleSprite = engine.loadSprite("INTDS.HSQ")
        self.skySprite = engine.loadSprite("SKY.HSQ")
        
        scrollAnimation = DuneAnimation<Int16>(from: 0, to: 152, startTime: 2.5, endTime: 6.5)
    }
    
    
    override func onDisable() {
        titleSprite = nil
        skySprite = nil
        currentTime = 0.0
    }
    
    
    override func update(_ elapsedTime: TimeInterval) {
        currentTime += elapsedTime
        
        if currentTime > 16.5 {
            engine.sendEvent(self, .nodeEnded)
            return
        }
    }
    
    
    override func render(_ buffer: PixelBuffer) {
        guard let titleSprite = titleSprite,
              let skySprite = skySprite,
              let scrollAnimation = scrollAnimation else {
            return
        }

        let scrollY = scrollAnimation.interpolate(currentTime)
        
        if contextBuffer.tag < 0x0011 {
            buffer.clearBuffer()
            titleSprite.setPalette()
            
            // Apply sky gradient with blue palette
            skySprite.setAlternatePalette(1)
            
            for x: Int16 in stride(from: 0, to: 320, by: 40) {
                skySprite.drawFrame(0, x: x, y: 0, buffer: contextBuffer)
                skySprite.drawFrame(1, x: x, y: 20, buffer: contextBuffer)
                skySprite.drawFrame(2, x: x, y: 40, buffer: contextBuffer)
                skySprite.drawFrame(3, x: x, y: 60, buffer: contextBuffer)
            }

            titleSprite.setPalette()
            titleSprite.drawFrame(1, x: 0, y: 44, buffer: contextBuffer)
            
            contextBuffer.tag = 0x0011
        }
        
        
        if scrollY < 152 && contextBuffer.tag < 0x0012 {
            var fxStart: SpriteEffect {
                if currentTime < 1.0 {
                    return .pixelate(end: 1.0, duration: 1.0, current: currentTime)
                }
                
                return .none
            }
            
            contextBuffer.render(to: buffer, effect: fxStart, y: Int(scrollY))
        }
        
        // Gradient sky and title fade
        if scrollY > 0 && contextBuffer.tag < 0x0012 && currentTime <= 9.5 {
            let skyScrollY = scrollY - 152
            titleSprite.drawFrame(2, x: 0, y: skyScrollY, buffer: buffer)
            titleSprite.drawFrame(3, x: 0, y: skyScrollY + 95, buffer: buffer)
            titleSprite.drawFrame(4, x: 0, y: skyScrollY + 123, buffer: buffer)
        
            if currentTime >= 7.5 {
                var fxTitle: SpriteEffect {
                    return .fadeIn(start: 7.5, duration: 2.0, current: currentTime)
                }
                
                titleSprite.drawFrame(5, x: 0, y: 48, buffer: buffer, effect: fxTitle)
            }
        }
        
        // Title fade out
        if currentTime > 9.5 {
            if contextBuffer.tag < 0x0012 {
                contextBuffer.clearBuffer()

                titleSprite.drawFrame(2, x: 0, y: 0, buffer: contextBuffer)
                titleSprite.drawFrame(3, x: 0, y: 95, buffer: contextBuffer)
                titleSprite.drawFrame(4, x: 0, y: 123, buffer: contextBuffer)
                titleSprite.drawFrame(5, x: 0, y: 48, buffer: contextBuffer)
                
                contextBuffer.tag = 0x0012

                engine.palette.stash()
            }
            
            var fxEnd: SpriteEffect {
                if currentTime >= 14.5 {
                    return .fadeOut(end: 16.5, duration: 2.0, current: currentTime)
                }

                return .none
            }

            contextBuffer.render(to: buffer, effect: fxEnd)
        }
    }
}
