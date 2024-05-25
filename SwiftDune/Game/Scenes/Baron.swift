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
    private var duration: TimeInterval = 3.0
    private var showSardaukar: Bool = false
    
    private var currentTime: TimeInterval = 0.0
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
        duration = 3.0
        showSardaukar = false
    }
    
    
    override func onParamsChange() {
        
        if let durationParam = params["duration"] {
            self.duration = durationParam as! TimeInterval
        }
        
        if let sardaukarParam = params["sardaukar"] {
            self.showSardaukar = sardaukarParam as! Bool
        }
    }
    
    
    override func update(_ elapsedTime: TimeInterval) {
        currentTime += elapsedTime
        
        if currentTime > duration {
            engine.sendEvent(self, .nodeEnded)
        }
    }
    
    
    override func render(_ buffer: PixelBuffer) {
        guard let baronSprite = baronSprite else {
            return
        }
        
        drawBackground(buffer: buffer)
        
        baronSprite.setPalette()
        baronSprite.drawAnimation(0, buffer: buffer, time: currentTime, offset: DunePoint(83, 0))
        
        if showSardaukar {
            drawAnimatedSardaukars(buffer: buffer, time: currentTime)
        }
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
    
    
    private func drawAnimatedSardaukars(buffer: PixelBuffer, time: Double) {
        guard let backgroundSprite = backgroundSprite else {
            return
        }
        
        let progress: Double = (time - 2.0) / 0.2
        let x: Int16 = -150 + Int16(Math.clampf(progress, 0.0, 1.0) * 150.0)
        
        backgroundSprite.drawFrame(5, x: x, y: 13, buffer: buffer)
        backgroundSprite.drawFrame(6, x: x, y: 13, buffer: buffer)
    }
}
