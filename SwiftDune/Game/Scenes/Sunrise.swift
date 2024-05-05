//
//  Sunrise.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 28/12/2023.
//

import Foundation

enum SunriseMode {
    case sunrise
    case sunset
    case daylight
}


final class Sunrise: DuneNode {
    private var contextBuffer = PixelBuffer(width: 320, height: 152)

    private var sunriseSprite: Sprite?
    private var chaniSprite: Sprite?
    private var lietSprite: Sprite?
    private var villageSprite: Sprite?

    private var currentTime: Double = 0.0
    private let engine = DuneEngine.shared
    
    private var currentPaletteIndex = -1
    private var currentPaletteStart = 3
    private var currentPaletteEnd = 3
    
    private var showFort = false
    private var fadeIn = false
    private var fadeOut = false
    private var zoomOut = false
    private var mode: SunriseMode = .sunrise
    private var character: DuneCharacter = .none
    private var totalDuration: Double = 4.0

    init() {
        super.init("Sunrise")
    }
    
    
    override func onEnable() {
        chaniSprite = engine.loadSprite("CHAN.HSQ")
        lietSprite = engine.loadSprite("KYNE.HSQ")
        villageSprite = engine.loadSprite("VILG.HSQ")
        sunriseSprite = engine.loadSprite("SUNRS.HSQ")
        sunriseSprite!.setPalette()
    }
    
    
    override func onDisable() {
        sunriseSprite = nil
        chaniSprite = nil
        villageSprite = nil
        currentPaletteIndex = -1
        currentPaletteStart = 3
        currentPaletteEnd = 3
        lietSprite = nil
        currentTime = 0.0
        character = .none
        totalDuration = 4.0
        showFort = false
        zoomOut = false
        fadeIn = false
        fadeOut = false
        mode = .daylight
    }
    
    
    override func onParamsChange() {
        if let duration = params["duration"] {
            self.totalDuration = duration as! Double
        }
        
        if let mode = params["mode"] {
            self.mode = mode as! SunriseMode
        }

        if let fort = params["fort"] {
            self.showFort = fort as! Bool
        }
        
        if let character = params["character"] {
            self.character = character as! DuneCharacter
        }

        if let fadeIn = params["fadeIn"] {
            self.fadeIn = fadeIn as! Bool
        }

        if let fadeOut = params["fadeOut"] {
            self.fadeOut = fadeOut as! Bool
        }

        if let zoomOut = params["zoomOut"] {
            self.zoomOut = zoomOut as! Bool
        }
    }
    
    
    override func update(_ elapsedTime: Double) {
        if currentTime > totalDuration {
            DuneEngine.shared.sendEvent(self, .nodeEnded)
            return
        }
        
        currentTime += elapsedTime
        
        if mode == .daylight {
            currentPaletteIndex = 3
        } else {
            let delayTime = fadeIn ? 2.0 : 0.0
            currentPaletteStart = mode == .sunrise ? 0 : 3
            currentPaletteEnd = mode == .sunrise ? 2 : 6
            
            let index = currentPaletteStart + Int(floor(currentTime - delayTime))
            currentPaletteIndex = Math.clamp(index, currentPaletteStart, currentPaletteEnd) % 6
        }
    }
    
    
    override func render(_ buffer: PixelBuffer) {
        drawDesertBackground(buffer: contextBuffer, effect: .none)

        if character == .chani {
            guard let chaniSprite = chaniSprite else {
                return
            }
            
            chaniSprite.setPalette()

            if zoomOut && currentTime < 2.0 {
                chaniSprite.drawAnimation(0, buffer: contextBuffer, time: 0.0)
            } else {
                chaniSprite.drawAnimation(0, buffer: contextBuffer, time: currentTime)
            }
        }

        if character == .liet {
            guard let lietSprite = lietSprite,
                  let villageSprite = villageSprite else {
                return
            }
            
            villageSprite.setPalette()
            villageSprite.drawFrame(24, x: 140, y: 3, buffer: contextBuffer)
            
            lietSprite.setPalette()
            lietSprite.drawAnimation(0, buffer: contextBuffer, time: currentTime)
        }
        
        
        var fx: SpriteEffect {
            if fadeIn && currentTime < 2.0 {
                return .fadeIn(start: 0.0, duration: 2.0, current: currentTime)
            }

            if fadeOut && currentTime > totalDuration - 2.0 {
                return .fadeOut(end: totalDuration, duration: 2.0, current: currentTime)
            }

            if zoomOut {
                if currentTime < 2.0 {
                    return .zoom(start: 0.0, duration: 2.0, current: currentTime, from: DuneRect(48, 48, 80, 38), to: DuneRect(48, 48, 80, 38))
                } else if currentTime >= 2.0 && currentTime <= 2.25 {
                    return .zoom(start: 2.0, duration: 0.25, current: currentTime, from: DuneRect(48, 48, 80, 38), to: DuneRect.fullScreen)
                }
            }

            return .none
        }

        contextBuffer.render(to: buffer, effect: fx)
        contextBuffer.tag = 0x0001
    }
    
    
    private func drawDesertBackground(buffer: PixelBuffer, effect: SpriteEffect) {
        guard let sunriseSprite = sunriseSprite else {
            return
        }
        
        if currentPaletteIndex != -1 {
            let delayTime = fadeIn ? 2.0 : 0.0

            if currentTime - delayTime < CGFloat(currentPaletteEnd - currentPaletteStart + 1) {
                let blendProgress = fmod(currentTime, 1.0)
                sunriseSprite.setAlternatePalette(currentPaletteIndex, max(0, currentPaletteIndex - 1), blend: blendProgress)
            } else {
                sunriseSprite.setAlternatePalette(currentPaletteIndex)
            }
        } else {
            sunriseSprite.setPalette()
        }

        sunriseSprite.drawFrame(2, x: 0, y: 0, buffer: buffer, effect: effect)
        sunriseSprite.drawFrame(3, x: 0, y: 25, buffer: buffer, effect: effect)
        sunriseSprite.drawFrame(4, x: 0, y: 50, buffer: buffer, effect: effect)
        sunriseSprite.drawFrame(5, x: 0, y: 74, buffer: buffer, effect: effect)
        sunriseSprite.drawFrame(6, x: 134, y: 92, buffer: buffer, effect: effect)
        sunriseSprite.drawFrame(0, x: 0, y: 102, buffer: buffer, effect: effect)
        
        if showFort {
            sunriseSprite.drawFrame(7, x: 19, y: 74, buffer: buffer, effect: effect)
        }
    }
}
