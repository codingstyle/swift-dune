//
//  DuneTitle.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 10/12/2023.
//

import Foundation

final class DuneTitle: DuneNode {
    private var contextBuffer = PixelBuffer(width: 320, height: 152)

    private var sky: Sky?
    private var titleSprite: Sprite?
    
    private var currentTime: TimeInterval = 0.0
    private let engine = DuneEngine.shared
    
    private var scrollAnimation: DuneAnimation<Int16>?
    
    init() {
        super.init("DuneTitle")
    }
    
    
    override func onEnable() {
        titleSprite = Sprite("INTDS.HSQ")
        sky = Sky()
        
        scrollAnimation = DuneAnimation<Int16>(from: 0, to: 152, startTime: 2.5, endTime: 6.5)
    }
    
    
    override func onDisable() {
        titleSprite = nil
        sky = nil
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
              let sky = sky,
              let scrollAnimation = scrollAnimation else {
            return
        }

        let scrollY = scrollAnimation.interpolate(currentTime)
        
        if contextBuffer.tag < 0x0011 {
            buffer.clearBuffer()
            titleSprite.setPalette()
            
            // Apply sky gradient with blue palette
            sky.lightMode = .day
            sky.render(contextBuffer)

            titleSprite.setPalette()
            titleSprite.drawFrame(1, x: 0, y: 44, buffer: contextBuffer)

            engine.palette.stash()
            
            contextBuffer.tag = 0x0011
        }
        
        
        if scrollY < 152 && contextBuffer.tag < 0x0012 {
            var fxStart: SpriteEffect {
                if currentTime < 2.0 {
                    return .pixelate(end: 2.0, duration: 2.0, current: currentTime)
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
            
            if currentTime > 7.5 {
                titleSprite.drawFrame(5, x: 0, y: 48, buffer: buffer)
            }

            // Partial palette fade in for the red title
            let clampedProgress = Math.clampf((currentTime - 7.5) / 2.0, 0.0, 1.0)
            Effects.fade(progress: clampedProgress, startIndex: 224, endIndex: 239)
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
