//
//  Death.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 02/08/2024.
//

import Foundation

final class Death: DuneNode {
    private let engine = DuneEngine.shared
    
    private var contextBuffer = PixelBuffer(width: 320, height: 152)
    private var deathSprite: Sprite?
    private var death2Sprite: Sprite?
    private var death3Sprite: Sprite?
    private var sky: Sky?
    private var duration: TimeInterval = 10.0
    private var currentTime: TimeInterval = 0.0
    
    init() {
        super.init("Death")
    }

    
    override func onEnable() {
        deathSprite = Sprite("DEATH1.HSQ")
        
        death2Sprite = Sprite("DEATH2.HSQ")
        death3Sprite = Sprite("DEATH3.HSQ")

        deathSprite!.moveAnimation(2, to: death3Sprite!)
        deathSprite!.moveAnimation(2, to: death3Sprite!)
        deathSprite!.moveAnimation(1, to: death2Sprite!)

        sky = Sky()
    }
    
    
    override func onDisable() {
        deathSprite = nil
        death2Sprite = nil
        death3Sprite = nil
        sky = nil
        currentTime = 0.0
    }
    
    
    override func update(_ elapsedTime: TimeInterval) {
        currentTime += elapsedTime
    }
    
    
    override func render(_ buffer: PixelBuffer) {
        guard let deathSprite = deathSprite,
              let death2Sprite = death2Sprite,
              let death3Sprite = death3Sprite,
              let sky = sky else {
            return
        }

        if contextBuffer.tag != 0x01 {
            sky.lightMode = .day
            sky.render(contextBuffer)
            
            deathSprite.drawFrame(0, x: 0, y: 42, buffer: contextBuffer)

            contextBuffer.tag = 0x01
        }
        
        contextBuffer.render(to: buffer, effect: .none)
        
        // 5 frames = (1.0 / 12.0) * 5
        if currentTime >= 0.0 && currentTime <= 0.416 {
            deathSprite.drawAnimation(0, buffer: buffer, time: currentTime, offset: .zero, loop: false)
        // 15 frames
        } else if currentTime > 0.416 && currentTime <= 1.666 {
            death2Sprite.drawAnimation(0, buffer: buffer, time: currentTime - 0.416, offset: .zero, loop: false)
        // 70 frames
        } else if currentTime > 1.666 && currentTime <= 5.835 {
            death3Sprite.drawAnimation(0, buffer: buffer, time: currentTime - 1.416, offset: .zero, loop: false)
        // 1 frame
        } else if currentTime > 5.835 {
            death3Sprite.drawAnimation(1, buffer: buffer, time: currentTime - 5.334, offset: .zero)
        }
    }
}
