//
//  IntroWorm.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 22/12/2023.
//

import Foundation

final class WormCall: DuneNode {
    private var contextBuffer = PixelBuffer(width: 320, height: 152)

    private var wormSprite: Sprite?
    private var sky: Sky?
    
    private var currentTime: TimeInterval = 0.0
    private let engine = DuneEngine.shared
    
    init() {
        super.init("WormCall")
    }

    
    override func onEnable() {
        wormSprite = Sprite("SHAI.HSQ")
        
        let worm2Sprite = Sprite("SHAI2.HSQ")
        wormSprite!.mergeFrames(with: worm2Sprite)
        
        sky = Sky()
    }
    
    
    override func onDisable() {
        wormSprite = nil
        sky = nil
        currentTime = 0.0
    }
    
    
    override func update(_ elapsedTime: TimeInterval) {
        currentTime += elapsedTime
                
        if currentTime > 9.41 {
            DuneEngine.shared.sendEvent(self, .nodeEnded)
        }
    }
    
    
    override func render(_ buffer: PixelBuffer) {
        guard let wormSprite = wormSprite,
              let sky = sky else {
            return
        }
        
        if contextBuffer.tag != 0x0001 {
            // Apply sky gradient with blue palette
            sky.lightMode = .day
            sky.render(contextBuffer)
 
            wormSprite.setPalette()
            wormSprite.drawFrame(44, x: 0, y: 74, buffer: contextBuffer)
 
            contextBuffer.tag = 0x0001

            engine.palette.stash()
        }

        var fx: SpriteEffect {
            if currentTime < 1.0 {
                return .fadeIn(start: 0.0, duration: 1.0, current: currentTime)
            } else if currentTime > 8.41 {
                return .fadeOut(end: 9.41, duration: 1.0, current: currentTime)
            }
            
            return .none
        }
        
        let intermediateFrameBuffer = engine.intermediateFrameBuffer

        intermediateFrameBuffer.clearBuffer()
        contextBuffer.render(to: intermediateFrameBuffer, effect: .none)
        
        if currentTime > 1.0 && currentTime < 8.41 {
            wormSprite.drawAnimation(0, buffer: intermediateFrameBuffer, time: currentTime - 1.0)
        }
        
        intermediateFrameBuffer.render(to: buffer, effect: fx)
    }
}
