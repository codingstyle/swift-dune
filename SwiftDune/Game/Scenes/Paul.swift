//
//  Paul.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 28/12/2023.
//

import Foundation

enum PaulBackground: String {
    case red = "BACK.HSQ"
    case mirror = "MIRROR.HSQ"
    case desert = "INTDS.HSQ"
}

final class Paul: DuneNode {
    private let engine = DuneEngine.shared
    private var currentTime: TimeInterval = 0.0
    private var contextBuffer = PixelBuffer(width: 320, height: 152)
    
    private var paulSprite: Sprite?
    private var chaniSprite: Sprite?
    private var backgroundSprite: Sprite?
    private var skySprite: Sprite?
    private var fadeIn: Bool = false
    private var fadeOut: Bool = false
    private var duration: TimeInterval = 8.0

    var background: PaulBackground
    
    init(_ background: PaulBackground = .red) {
        self.background = background
        super.init("Paul")
    }
    
    
    override func onEnable() {
        paulSprite = engine.loadSprite("PAUL.HSQ")
        chaniSprite = engine.loadSprite("CHAN.HSQ")
        skySprite = engine.loadSprite("SKY.HSQ")
        backgroundSprite = engine.loadSprite(background.rawValue)
    }
    
    
    override func onDisable() {
        paulSprite = nil
        chaniSprite = nil
        backgroundSprite = nil
        skySprite = nil
        fadeIn = false
        fadeOut = false
        duration = 8.0
        currentTime = 0.0
        contextBuffer.tag = 0x0
        contextBuffer.clearBuffer()
    }
    
    
    override func onParamsChange() {
        if let backgroundParam = params["background"] {
            self.background = backgroundParam as! PaulBackground
            backgroundSprite = engine.loadSprite(background.rawValue)
        }
        
        if let fadeInParam = params["fadeIn"] {
            self.fadeIn = fadeInParam as! Bool
        }

        if let fadeOutParam = params["fadeOut"] {
            self.fadeOut = fadeOutParam as! Bool
        }
        
        if let durationParam = params["duration"] {
            self.duration = durationParam as! TimeInterval
        }
    }
    
    
    override func update(_ elapsedTime: TimeInterval) {
        currentTime += elapsedTime
        
        if currentTime > 8.0 {
            DuneEngine.shared.sendEvent(self, .nodeEnded)
        }
    }
    
    
    override func render(_ buffer: PixelBuffer) {
        guard let paulSprite = paulSprite,
              let backgroundSprite = backgroundSprite else {
            return
        }
        
        if currentTime < 2.0  {
            if contextBuffer.tag != 0x0001 {
                backgroundSprite.setPalette()
                drawBackground(buffer: buffer)
                
                paulSprite.setPalette()
                paulSprite.drawAnimation(0, buffer: buffer, time: 16.0 * 40.0)
                
                contextBuffer.copyPixels(from: buffer)
                contextBuffer.tag = 0x0001
            }
            
            var fx: SpriteEffect {
                if fadeIn {
                    return .fadeIn(start: 0.0, duration: 2.0, current: currentTime)
                } else {
                    return .none
                }
            }
            
            contextBuffer.render(to: buffer, effect: fx)
        }
        
        if currentTime >= 2.0 && currentTime <= duration - 2.0 {
            backgroundSprite.setPalette()
            drawBackground(buffer: buffer)

            paulSprite.setPalette()
            paulSprite.drawAnimation(0, buffer: buffer, time: currentTime - 2.0 + (0.016 * 40.0))
        }
        
        
        if currentTime > duration - 2.0 {
            if contextBuffer.tag != 0x0002 {
                contextBuffer.clearBuffer()
                
                backgroundSprite.setPalette()
                drawBackground(buffer: contextBuffer)

                paulSprite.setPalette()
                paulSprite.drawAnimation(0, buffer: contextBuffer, time: currentTime - 2.0 + (0.016 * 40.0))
                contextBuffer.tag = 0x0002
            }
            
            var fx: SpriteEffect {
                if fadeOut {
                    return .fadeOut(end: duration, duration: 2.0, current: currentTime)
                } else {
                    return .none
                }
            }
            
            contextBuffer.render(to: buffer, effect: fx)
        }
        
        if background == .mirror {
            backgroundSprite.setPalette()
            backgroundSprite.drawFrame(2, x: 0, y: 0, buffer: buffer)
            paulSprite.setPalette()
        }
    }
    
    
    private func drawBackground(buffer: PixelBuffer) {
        contextBuffer.clearBuffer()
        
        switch background {
        case .red:
            drawRedBackground(buffer: buffer)
            break
        case .mirror:
            drawMirrorBackground(buffer: buffer)
            break
        case .desert:
            drawDesertBackground(buffer: buffer)
            break
        }
    }
    
    
    private func drawRedBackground(buffer: PixelBuffer) {
        guard let backgroundSprite = backgroundSprite else {
            return
        }
        
        backgroundSprite.drawFrame(0, x: 0, y: 0, buffer: buffer)
        backgroundSprite.drawFrame(1, x: 52, y: 25, buffer: buffer)
        backgroundSprite.drawFrame(2, x: 108, y: 51, buffer: buffer)
    }
    
    
    private func drawMirrorBackground(buffer: PixelBuffer) {
        guard let backgroundSprite = backgroundSprite else {
            return
        }
        
        backgroundSprite.drawFrame(0, x: 0, y: 0, buffer: buffer)
        backgroundSprite.drawFrame(1, x: 0, y: 0, buffer: buffer)
    }
    
    
    private func drawDesertBackground(buffer: PixelBuffer) {
        guard let backgroundSprite = backgroundSprite,
              let skySprite = skySprite else {
            return
        }
        
        // Apply sky gradient with blue palette
        skySprite.setAlternatePalette(1)
        
        for x: Int16 in stride(from: 0, to: 320, by: 40) {
            skySprite.drawFrame(0, x: x, y: 0, buffer: buffer)
            skySprite.drawFrame(1, x: x, y: 20, buffer: buffer)
            skySprite.drawFrame(2, x: x, y: 40, buffer: buffer)
            skySprite.drawFrame(3, x: x, y: 60, buffer: buffer)
        }

        // Desert background
        backgroundSprite.setPalette()
        backgroundSprite.drawFrame(0, x: 0, y: 60, buffer: buffer)
    }
}
