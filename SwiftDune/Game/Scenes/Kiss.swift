//
//  Kiss.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 10/02/2024.
//

import Foundation


final class Kiss: DuneNode {
    private var contextBuffer = PixelBuffer(width: 320, height: 152)

    private var kissSprite: Sprite?
    private var dunesSprite: Sprite?
    private var skySprite: Sprite?

    private var currentTime: Double = 0.0
    private let engine = DuneEngine.shared
    
    init() {
        super.init("Kiss")
    }
    
    
    override func onEnable() {
        kissSprite = Sprite("CHANKISS.HSQ")
        skySprite = Sprite("SKY.HSQ")
        dunesSprite = Sprite("DUNES.HSQ")
    }
    
    
    override func onDisable() {
        kissSprite = nil
        skySprite = nil
        dunesSprite = nil
    }
    
    
    override func update(_ elapsedTime: Double) {
        currentTime += elapsedTime
        
        if currentTime > 10.0 {
            engine.sendEvent(self, .nodeEnded)
        }
    }
    
    
    override func render(_ buffer: PixelBuffer) {
        guard let skySprite = skySprite,
              let kissSprite = kissSprite,
              let dunesSprite = dunesSprite else {
            return
        }
        
        if contextBuffer.tag != 0x0001 {
            skySprite.setAlternatePalette(3)

            for x: Int16 in stride(from: 0, to: 320, by: 40) {
                skySprite.drawFrame(0, x: x, y: 0, buffer: contextBuffer)
                skySprite.drawFrame(1, x: x, y: 20, buffer: contextBuffer)
                skySprite.drawFrame(2, x: x, y: 40, buffer: contextBuffer)
                skySprite.drawFrame(3, x: x, y: 60, buffer: contextBuffer)
            }
            
            Primitives.fillRect(DuneRect(0, 78, 320, 74), 63, contextBuffer)
            
            // TODO: map accurate background once flight animation is reverse-engineered

            dunesSprite.drawFrame(0, x: 62, y: 77, buffer: contextBuffer, effect: .transform(scale: 0.1))
            dunesSprite.drawFrame(6, x: 174, y: 77, buffer: contextBuffer, effect: .transform(scale: 0.2))
            dunesSprite.drawFrame(7, x: 120, y: 77, buffer: contextBuffer, effect: .transform(scale: 0.2))
            dunesSprite.drawFrame(3, x: 19, y: 77, buffer: contextBuffer, effect: .transform(scale: 0.15))
            dunesSprite.drawFrame(1, x: 240, y: 77, buffer: contextBuffer, effect: .transform(scale: 0.15))
            dunesSprite.drawFrame(2, x: 27, y: 78, buffer: contextBuffer, effect: .transform(scale: 0.35))
            dunesSprite.drawFrame(16, x: 280, y: 56, buffer: contextBuffer, effect: .transform(scale: 0.4))
            dunesSprite.drawFrame(1, x: 108, y: 74, buffer: contextBuffer, effect: .transform(scale: 0.5))
            dunesSprite.drawFrame(4, x: 108, y: 77, buffer: contextBuffer)

            contextBuffer.tag = 0x0001
        }

        kissSprite.setPalette()
        
        if currentTime < 5.0 {
            contextBuffer.render(to: buffer, effect: .none)
            kissSprite.drawFrame(0, x: 78, y: 32, buffer: buffer)
        } else {
            let zoomRect = DuneRect(0, 52, 210, 100)
            contextBuffer.render(to: buffer, effect: .zoom(start: 5.0, duration: 10.0, current: currentTime, from: zoomRect, to: zoomRect))
            kissSprite.drawFrame(1, x: 25, y: 4, buffer: buffer)
        }
    }
}
