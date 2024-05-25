//
//  LogoSwap.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 07/01/2024.
//

import Foundation
import AppKit

final class LogoSwap: DuneNode {
    private var contextBuffer = PixelBuffer(width: 320, height: 152)
    private var currentTime: TimeInterval = 5.32
    private var cryoSprite: Sprite?

    private let engine = DuneEngine.shared
    
    // Keyframes
    let cryoLogo = AnimationTimeRange(start: 5.32, end: 6.60)
    let virginLogo = AnimationTimeRange(start: 6.67, end: 9.35)

    init() {
        super.init("LogoSwap")
    }
    
    
    override func onEnable() {
        cryoSprite = engine.loadSprite("CRYO.HSQ")
        cryoSprite!.setPalette()
    }

    
    override func onDisable() {
        cryoSprite = nil
        currentTime = 0.0
    }
    
    
    override func update(_ elapsedTime: TimeInterval) {
        currentTime += elapsedTime
        
        if currentTime > virginLogo.end {
            engine.sendEvent(self, .nodeEnded)
        }
    }
    
    
    func animation(is animTick: AnimationTimeRange) -> Bool {
        return currentTime >= animTick.start && currentTime <= animTick.end
    }
    
    
    override func render(_ buffer: PixelBuffer) {
        guard let cryoSprite = cryoSprite else {
            return
        }
        
        if animation(is: cryoLogo) {
            buffer.clearBuffer()

            if contextBuffer.tag != 0x0001 {
                contextBuffer.clearBuffer()

                cryoSprite.drawFrame(0, x: 113, y: 15, buffer: contextBuffer)
                cryoSprite.drawFrame(1, x: 113, y: 15, buffer: contextBuffer)
                cryoSprite.drawFrame(2, x: 113, y: 15, buffer: contextBuffer)
                cryoSprite.drawFrame(3, x: 113, y: 15, buffer: contextBuffer)
                cryoSprite.drawFrame(4, x: 113, y: 15, buffer: contextBuffer)
                
                contextBuffer.tag = 0x0001
            }
            
            var fx: SpriteEffect {
                if currentTime >= cryoLogo.end - 0.3 {
                    return .flipOut(end: cryoLogo.end, duration: 0.3, current: currentTime)
                } else {
                    return .none
                }
            }

            contextBuffer.render(to: buffer, effect: fx)
            return
        }
        
        if animation(is: virginLogo) {
            buffer.clearBuffer()

            if contextBuffer.tag != 0x0002 {
                contextBuffer.clearBuffer()
                
                cryoSprite.drawFrame(5, x: 98, y: 13, buffer: contextBuffer)
                cryoSprite.drawFrame(6, x: 98, y: 118, buffer: contextBuffer)

                contextBuffer.tag = 0x0002
            }

            var fx: SpriteEffect {
                if currentTime <= virginLogo.start + 0.3 {
                    return .flipIn(start: virginLogo.start, duration: 0.3, current: currentTime)
                } else if currentTime >= virginLogo.end - 0.9 {
                    return .fadeOut(end: virginLogo.end, duration: 0.9, current: currentTime)
                } else {
                    return .none
                }
            }

            contextBuffer.render(to: buffer, effect: fx)
            return
        }
    }
}
