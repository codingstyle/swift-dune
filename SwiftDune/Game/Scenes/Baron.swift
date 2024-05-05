//
//  Baron.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 17/01/2024.
//

import Foundation

final class Baron: DuneNode {
    private var contextBuffer = PixelBuffer(width: 320, height: 152)
    
    private var baronSprite: Sprite?
    private var backgroundSprite: Sprite?
    
    private var currentTime: Double = 0.0
    private let engine = DuneEngine.shared
    
    init() {
        super.init("Baron")
    }
    
    
    override func onEnable() {
        baronSprite = engine.loadSprite("BARO.HSQ")
        backgroundSprite = engine.loadSprite("BACK.HSQ")
    }
    
    
    override func onDisable() {
        baronSprite = nil
        backgroundSprite = nil
        currentTime = 0.0
    }
    
    
    override func update(_ elapsedTime: Double) {
        currentTime += elapsedTime
        
        if currentTime > 8.0 {
            DuneEngine.shared.sendEvent(self, .nodeEnded)
        }
    }
    
    
    override func render(_ buffer: PixelBuffer) {
        guard let baronSprite = baronSprite else {
            return
        }
        
        drawBackground(buffer: buffer)
        
        baronSprite.setPalette()
        baronSprite.drawAnimation(0, buffer: buffer, time: currentTime, offset: DunePoint(83, 0))
    }
    
    
    private func drawBackground(buffer: PixelBuffer) {
        guard let backgroundSprite = backgroundSprite else {
            return
        }
        
        backgroundSprite.setPalette()
        backgroundSprite.drawFrame(4, x: 0, y: 0, buffer: buffer, effect: .transform(flipX: true, flipY: false))
        backgroundSprite.drawFrame(4, x: 236, y: 0, buffer: buffer)
        backgroundSprite.drawFrame(3, x: 84, y: 0, buffer: buffer)
    }
}
