//
//  DesertWalk.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 16/06/2024.
//

import Foundation

final class DesertWalk: DuneNode {
    private let engine = DuneEngine.shared
    private var contextBuffer = PixelBuffer(width: 320, height: 152)

    private var dunesSprite: Sprite?
    private var dunes2Sprite: Sprite?
    private var sky: Sky?
    private var dayMode: DuneLightMode = .day
    
    private var currentTime: TimeInterval = 0.0
    private var duration: TimeInterval = 16.0
    
    init() {
        super.init("DesertWalk")
    }
    
    
    override func onEnable() {
        dunesSprite = Sprite("DUNES.HSQ")
        dunes2Sprite = Sprite("DUNES2.HSQ")
        sky = Sky()
    }
    
    
    override func onDisable() {
        currentTime = 0.0
        duration = 16.0
        dunesSprite = nil
        dunes2Sprite = nil
        sky = nil
    }
    
    
    override func onParamsChange() {
        if let dayMode = params["dayMode"] {
            self.dayMode = dayMode as! DuneLightMode
        }

        if let duration = params["duration"] {
            self.duration = duration as! TimeInterval
        }
    }
    
    
    override func update(_ elapsedTime: TimeInterval) {
        currentTime += elapsedTime
        
        if currentTime > duration {
            engine.sendEvent(self, .nodeEnded)
            return
        }
        
        guard let sky = sky else {
            return
        }
        
        sky.lightMode = dayMode
    }
    
    
    override func render(_ buffer: PixelBuffer) {
        guard let dunesSprite = dunesSprite,
              let dunes2Sprite = dunes2Sprite else {
            return
        }

        drawBackground(buffer)

        // Dunes background
        dunesSprite.drawFrame(4, x: 0, y: 78, buffer: buffer, effect: .transform(scale: 0.2))
        dunesSprite.drawFrame(1, x: 34, y: 77, buffer: buffer, effect: .transform(scale: 0.1))
        dunesSprite.drawFrame(6, x: 143, y: 77, buffer: buffer, effect: .transform(scale: 0.2))

        dunesSprite.drawFrame(0, x: 260, y: 78, buffer: buffer, effect: .transform(scale: 0.15))
        dunesSprite.drawFrame(4, x: 243, y: 77, buffer: buffer, effect: .transform(scale: 0.2))

        dunesSprite.drawFrame(4, x: 83, y: 77, buffer: buffer, effect: .transform(scale: 0.1))
        dunesSprite.drawFrame(2, x: 62, y: 78, buffer: buffer, effect: .transform(scale: 0.15))

        // Arrakeen
        dunes2Sprite.drawFrame(16, x: 160, y: 12, buffer: buffer)
        
        // Dunes foreground
        dunesSprite.drawFrame(0, x: 210, y: 72, buffer: buffer)
        dunesSprite.drawFrame(4, x: 10, y: 76, buffer: buffer)

        engine.palette.stash()
    }
    
    
    private func drawBackground(_ buffer: PixelBuffer) {
        if contextBuffer.tag == dayMode.asInt {
            contextBuffer.render(to: buffer, effect: .none)
            return
        }
        
        guard let sky = sky else {
            return
        }
        
        sky.render(contextBuffer)

        Primitives.fillRect(DuneRect(0, 76, 320, 76), 63, contextBuffer)
        
        contextBuffer.render(to: buffer, effect: .none)
        contextBuffer.tag = dayMode.asInt
    }
}
