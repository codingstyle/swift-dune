//
//  IntroWorm.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 22/12/2023.
//

import Foundation

final class WormCall: DuneNode {
    private var contextBuffer = PixelBuffer(width: 320, height: 152)

    private var wormSound: Sound?
    private var wormSprite: Sprite?
    private var sky: Sky?
    
    init() {
        super.init("WormCall")
    }

    
    override func onEnable() {
        wormSprite = Sprite("SHAI.HSQ")
        
        let worm2Sprite = Sprite("SHAI2.HSQ")
        wormSprite!.mergeFrames(with: worm2Sprite)

        wormSound = Sound("SD8.HSQ", player: engine.audioPlayer)
        wormSound!.skipRepeat = true

        sky = Sky()
    }
    
    
    override func onDisable() {
        wormSprite = nil
        wormSound = nil
        sky = nil
        currentTime = 0.0
    }
    
    
    override func update(_ elapsedTime: TimeInterval) {
        if currentTime == 0.0 && !(wormSound!.isPlaying) {
            engine.audioPlayer.play(wormSound!)
        }
      
        currentTime += elapsedTime
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
        }
        
        contextBuffer.render(to: buffer)
        wormSprite.drawAnimation(0, buffer: buffer, time: currentTime)
    }
}
