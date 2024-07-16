//
//  Presents.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 08/10/2023.
//

import Foundation
import AppKit

struct AnimationTimeRange {
    var start: Double
    var end: Double
}

final class Presents: DuneNode {
    private let engine = DuneEngine.shared

    private var contextBuffer = PixelBuffer(width: 320, height: 152)
    private var currentTime: TimeInterval = 0.0

    private var introSprite: Sprite?

    // Keyframes
    let virginPresents = AnimationTimeRange(start: 0.00, end: 3.71)
    let cryoPresents = AnimationTimeRange(start: 3.96, end: 9.47)

    init() {
        super.init("Presents")
    }
    
    
    override func onEnable() {
        introSprite = engine.loadSprite("INTDS.HSQ")
    }

    
    override func onDisable() {
        introSprite = nil
        currentTime = 0.0
    }
    
    
    override func update(_ elapsedTime: TimeInterval) {
        currentTime += elapsedTime
        
        if currentTime > cryoPresents.end {
            engine.sendEvent(self, .nodeEnded)
        }
    }
    
    
    func animation(is animTick: AnimationTimeRange) -> Bool {
        return currentTime >= animTick.start && currentTime <= animTick.end
    }
    
    
    override func render(_ buffer: PixelBuffer) {
        guard let introSprite = introSprite else {
            return
        }
        
        // Virgin Games presents
        if animation(is: virginPresents) {
            if contextBuffer.tag != 0x0003 {
                introSprite.setPalette()

                contextBuffer.clearBuffer()
                introSprite.drawFrame(6, x: 62, y: 58, buffer: contextBuffer)
                introSprite.drawFrame(7, x: 114, y: 90, buffer: contextBuffer)

                contextBuffer.tag = 0x0003
                engine.palette.stash()
            }

            var fx: SpriteEffect {
                if currentTime <= virginPresents.start + 0.9 {
                    return .fadeIn(start: virginPresents.start, duration: 0.9, current: currentTime)
                } else if currentTime >= virginPresents.end - 0.9 {
                    return .fadeOut(end: virginPresents.end, duration: 0.9, current: currentTime)
                } else {
                    return .none
                }
            }
            
            contextBuffer.render(to: buffer, effect: fx)
            return
        }

        // A production from Cryo Interactive Entertainment Systems
        if animation(is: cryoPresents) {
            if contextBuffer.tag != 0x0004 {
                contextBuffer.clearBuffer()
                introSprite.setPalette()
                
                introSprite.drawFrame(8, x: 76, y: 43, buffer: contextBuffer)
                introSprite.drawFrame(9, x: 132, y: 71, buffer: contextBuffer)
                introSprite.drawFrame(10, x: 14, y: 96, buffer: contextBuffer)

                contextBuffer.tag = 0x0004
                engine.palette.stash()
            }
            
            var fx: SpriteEffect {
                if currentTime <= cryoPresents.start + 0.9 {
                    return .fadeIn(start: cryoPresents.start, duration: 0.9, current: currentTime)
                } else if currentTime >= cryoPresents.end - 0.9 {
                    return .fadeOut(end: cryoPresents.end, duration: 0.9, current: currentTime)
                } else {
                    return .none
                }
            }
            
            contextBuffer.render(to: buffer, effect: fx)
            return
        }
    }
}
