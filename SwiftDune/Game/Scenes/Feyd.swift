//
//  Feyd.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 17/01/2024.
//

import Foundation

final class Feyd: DuneNode {
    private var contextBuffer = PixelBuffer(width: 320, height: 152)
    
    private var feydSprite: Sprite?
    private var backgroundSprite: Sprite?
    
    private var currentTime: TimeInterval = 0.0
    private let engine = DuneEngine.shared
    
    init() {
        super.init("Feyd")
    }
    
    
    override func onEnable() {
        feydSprite = Sprite("FEYD.HSQ")
        backgroundSprite = Sprite("BACK.HSQ")
    }
    
    
    override func onDisable() {
        feydSprite = nil
        backgroundSprite = nil
        currentTime = 0.0
    }
    
    
    override func update(_ elapsedTime: TimeInterval) {
        currentTime += elapsedTime
        
        if currentTime > 8.0 {
            DuneEngine.shared.sendEvent(self, .nodeEnded)
        }
    }
    
    
    override func render(_ buffer: PixelBuffer) {
        guard let feydSprite = feydSprite else {
            return
        }
        
        if contextBuffer.tag != 0x0001 {
            drawBackground()
            contextBuffer.tag = 0x0001
        }
        
        contextBuffer.render(to: buffer, effect: .none)
        
        if currentTime <= 1.5 {
            feydSprite.drawAnimation(1, buffer: buffer, time: currentTime, offset: DunePoint(66, 0))
        } else {
            feydSprite.drawAnimation(4, buffer: buffer, time: currentTime, offset: DunePoint(66, 0))
        }
    }
    
    
    private func drawBackground() {
        guard let backgroundSprite = backgroundSprite,
              let feydSprite = feydSprite else {
            return
        }

        feydSprite.setPalette()
        Primitives.fillRect(DuneRect(84, 0, 152, 152), 48, contextBuffer, isOffset: false)

        // Background
        backgroundSprite.setPalette()

        backgroundSprite.drawFrame(4, x: 0, y: 0, buffer: contextBuffer, effect: .transform(flipX: true))
        backgroundSprite.drawFrame(4, x: 236, y: 0, buffer: contextBuffer)
        
        // Sardaukars
        backgroundSprite.drawFrame(5, x: -53, y: 8, buffer: contextBuffer)
        backgroundSprite.drawFrame(6, x: -53, y: 8, buffer: contextBuffer)

        backgroundSprite.drawFrame(5, x: 0, y: 13, buffer: contextBuffer)
        backgroundSprite.drawFrame(6, x: 0, y: 13, buffer: contextBuffer)

        backgroundSprite.drawFrame(7, x: 200, y: 13, buffer: contextBuffer)
        backgroundSprite.drawFrame(8, x: 200, y: 13, buffer: contextBuffer)

        feydSprite.setPalette()
    }
}
