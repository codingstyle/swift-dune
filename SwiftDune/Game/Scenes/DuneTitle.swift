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
    private var scrollAnimation: DuneAnimation<Int16>?
    
    init() {
        super.init("DuneTitle")
    }
    
    
    override func onEnable() {
        titleSprite = Sprite("INTDS.HSQ")
        sky = Sky()
        
        scrollAnimation = DuneAnimation<Int16>(from: 0, to: 152, startTime: 0.5, endTime: 4.5)
    }
    
    
    override func onDisable() {
        titleSprite = nil
        scrollAnimation = nil
        sky = nil
        currentTime = 0.0
    }
    
    
    override func update(_ elapsedTime: TimeInterval) {
        currentTime += elapsedTime
    }
    
    
    override func render(_ buffer: PixelBuffer) {
        guard let titleSprite = titleSprite,
              let sky = sky,
              let scrollAnimation = scrollAnimation else {
            return
        }

        let scrollY = scrollAnimation.interpolate(currentTime)
        
        if contextBuffer.tag < 0x0011 {
            titleSprite.setPalette()
            
            // Apply sky gradient with blue palette
            sky.lightMode = .day
            sky.render(contextBuffer)

            titleSprite.setPalette()
            titleSprite.drawFrame(1, x: 0, y: 44, buffer: contextBuffer)

            contextBuffer.tag = 0x0011
        }

        if scrollY < 152 {
            contextBuffer.render(to: buffer, y: Int(scrollY))
        }

        // Gradient sky and scroll
        if scrollY > 0 && contextBuffer.tag < 0x0012 && currentTime <= 5.5 {
            let skyScrollY = scrollY - 152
            titleSprite.drawFrame(2, x: 0, y: skyScrollY, buffer: buffer)
            titleSprite.drawFrame(3, x: 0, y: skyScrollY + 95, buffer: buffer)
            titleSprite.drawFrame(4, x: 0, y: skyScrollY + 123, buffer: buffer)
        }
        
        // Title fade in & fade out
        if currentTime > 5.5 {
            if contextBuffer.tag < 0x0012 {
                contextBuffer.clearBuffer()

                titleSprite.drawFrame(2, x: 0, y: 0, buffer: contextBuffer)
                titleSprite.drawFrame(3, x: 0, y: 95, buffer: contextBuffer)
                titleSprite.drawFrame(4, x: 0, y: 123, buffer: contextBuffer)
                titleSprite.drawFrame(5, x: 0, y: 48, buffer: contextBuffer)
                
                contextBuffer.tag = 0x0012
                engine.palette.stash()
            }
  
            // Partial palette fade in for the red title
            if currentTime < 7.6 {
                let clampedProgress = Math.clampf((currentTime - 5.5) / 2.0, 0.0, 1.0)
                Effects.fade(progress: clampedProgress, startIndex: 224, endIndex: 239)
            }
            
            contextBuffer.render(to: buffer)
        }
    }
}
