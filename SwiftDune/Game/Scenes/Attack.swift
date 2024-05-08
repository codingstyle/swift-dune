//
//  Attack.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 08/05/2024.
//

import Foundation

final class Attack: DuneNode {
    private let engine = DuneEngine.shared
    
    private var contextBuffer = PixelBuffer(width: 320, height: 152)
    private var attackSprite: Sprite?
    private var duration: Double = 10.0
    private var currentTime: Double = 0.0
    
    init() {
        super.init("Attack")
    }

    
    override func onEnable() {
        attackSprite = Sprite("ATTACK.HSQ")
    }
    
    
    override func onDisable() {
        attackSprite = nil
        currentTime = 0.0
    }
    
    
    override func update(_ elapsedTime: Double) {
        currentTime += elapsedTime
        
        if currentTime > duration {
            engine.sendEvent(self, .nodeEnded)
        }
    }
    
    
    override func render(_ buffer: PixelBuffer) {
        guard let attackSprite = attackSprite else {
            return
        }
        
        if contextBuffer.tag != 0x01 {
            contextBuffer.clearBuffer()
            
            for x: Int16 in stride(from: 0, to: 320, by: 40) {
                attackSprite.drawFrame(2, x: x, y: 0, buffer: contextBuffer)
                attackSprite.drawFrame(3, x: x, y: 81, buffer: contextBuffer)
            }

            attackSprite.drawFrame(49, x: 0, y: 76, buffer: contextBuffer)
            attackSprite.drawFrame(1, x: 0, y: 134, buffer: contextBuffer)
        }
        
        contextBuffer.copyPixels(to: buffer)
    }
}
