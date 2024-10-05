//
//  Stars.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 07/01/2024.
//

import Foundation
import AppKit


enum StarsMode {
    case stars
    case planets
    case planetsPan
    case arrakisZoom
    case globe
}

final class Stars: DuneNode {
    private let engine = DuneEngine.shared
    private var contextBuffer = PixelBuffer(width: 320, height: 152)

    private var starsSprite: Sprite?
    private var globe: Globe?

    private var currentTime: TimeInterval = 0.0
    private var duration: TimeInterval = 0.0
    private var mode: StarsMode = .stars
    private var transitionIn: TransitionEffect = .none

    init() {
        super.init("Stars")
    }
    
    
    override func onEnable() {
        starsSprite = Sprite("STARS.HSQ")
        starsSprite!.setPalette()
        
        if mode == .globe {
            globe = Globe()
            globe!.setOrientation(tilt: 40, rotation: 5000)
        }
    }

    
    override func onDisable() {
        starsSprite = nil
        globe = nil
        currentTime = 0.0
        mode = .stars
        duration = 0.0
        transitionIn = .none
        
        contextBuffer.clearBuffer()
        contextBuffer.tag = 0x0
    }
    
    
    override func onParamsChange() {
        if let modeParam = params["mode"] {
            self.mode = modeParam as! StarsMode
        }

        if let transitionInParam = params["transitionIn"] {
            self.transitionIn = transitionInParam as! TransitionEffect
        }

        if let durationParam = params["duration"] {
            self.duration = durationParam as! TimeInterval
        }
    }
    
    
    override func update(_ elapsedTime: TimeInterval) {
        currentTime += elapsedTime
        
        if let globe = globe {
            globe.update(currentTime)
        }
        
        if duration > 0.0 && currentTime > duration {
            engine.sendEvent(self, .nodeEnded)
        }
    }
    
    
    override func render(_ buffer: PixelBuffer) {
        switch mode {
        case .stars:
            drawStars(buffer)
            break
        case .planets:
            drawFixedPlanets(buffer)
            break
        case .planetsPan:
            drawPlanetPan(buffer)
            break
        case .arrakisZoom:
            drawArrakisZoom(buffer)
            break
        case .globe:
            drawGlobe(buffer)
            break
        }
    }
    
    
    private func drawStars(_ buffer: PixelBuffer) {
        guard let starsSprite = starsSprite else {
            return
        }
        
        if contextBuffer.tag != 0x0008 {
            contextBuffer.clearBuffer()
            starsSprite.setPalette()
            starsSprite.drawFrame(0, x: 0, y: 0, buffer: contextBuffer)
            
            contextBuffer.tag = 0x0008

            engine.palette.stash()
        }
        
        var fx: SpriteEffect {
            switch transitionIn {
            case .fadeIn(let fadeDuration):
                return .fadeIn(start: 0.0, duration: fadeDuration, current: currentTime)
            default:
                return .none
            }
        }
        
        contextBuffer.render(to: buffer, effect: fx)
    }
    
    
    private func drawGlobe(_ buffer: PixelBuffer) {
        guard let globe = globe else {
            return
        }
        
        drawStars(buffer)
        globe.render(buffer: buffer)
    }
    
    
    private func drawFixedPlanets(_ buffer: PixelBuffer) {
        guard let starsSprite = starsSprite else {
            return
        }
        
        if contextBuffer.tag != 0x0005 {
            contextBuffer.clearBuffer()
            starsSprite.setPalette()
            starsSprite.drawFrame(0, x: 0, y: 0, buffer: contextBuffer)
            starsSprite.drawFrame(1, x: 302, y: 0, buffer: contextBuffer)
            starsSprite.drawFrame(2, x: 604, y: 0, buffer: contextBuffer)
            starsSprite.drawFrame(36, x: 45, y: 60, buffer: contextBuffer)
            starsSprite.drawFrame(3, x: 124, y: 72, buffer: contextBuffer)
            starsSprite.drawFrame(37, x: 235, y: 106, buffer: contextBuffer)

            contextBuffer.tag = 0x0005

            engine.palette.stash()
        }

        var fx: SpriteEffect {
            switch transitionIn {
            case .fadeIn(let fadeDuration):
                return .fadeIn(start: 0.0, duration: fadeDuration, current: currentTime)
            default:
                return .none
            }
        }
        
        contextBuffer.render(to: buffer, effect: fx)
    }
    
    
    private func drawPlanetPan(_ buffer: PixelBuffer) {
        guard let starsSprite = starsSprite else {
            return
        }
        
        buffer.clearBuffer()

        let ratio = currentTime / duration
        let scrollX = Int16(604.0 * ratio)
        
        starsSprite.setPalette()
        starsSprite.drawFrame(0, x: 0 - scrollX, y: 0, buffer: buffer)
        starsSprite.drawFrame(1, x: 302 - scrollX, y: 0, buffer: buffer)
        starsSprite.drawFrame(2, x: 604 - scrollX, y: 0, buffer: buffer)
        starsSprite.drawFrame(36, x: 45 - scrollX * 2, y: 60, buffer: buffer)

        // Arrakis rotation = frames 3 to 35
        let arrakisIndex = 3 + UInt16(32.0 * ratio)
        let firstArrakisFrameInfo = starsSprite.frame(at: 3) // 124 x 72
        let firstDelta = (Int16(320 - firstArrakisFrameInfo.width) / 2) - 124
        
        let arrakisFrameInfo = starsSprite.frame(at: Int(arrakisIndex))
        let ax = (Int16(320 - arrakisFrameInfo.width) / 2) - Int16((1.0 - ratio) * Double(firstDelta))
        let ay = Int16(152 - arrakisFrameInfo.height) / 2
        starsSprite.drawFrame(arrakisIndex, x: ax, y: ay, buffer: buffer)

        //engine.logger.log(.debug, "ARRAKIS -> frameIndex: \(arrakisIndex), x=\(ax), y=\(ay)")
       
        // Red planet shift: frames 37 to 44
        let redPlanetIndex = 37 + UInt16(7.0 * ratio)
        let redPlanetFrameInfo = starsSprite.frame(at: Int(redPlanetIndex))
        let rx = ratio < 0.5 ? Int16(235 + (80 * ratio * 2)) : Int16(315 - (315 * (ratio - 0.5) * 3))
        let ry = Int16(76) + Int16(76 - redPlanetFrameInfo.height) / 2
        starsSprite.drawFrame(redPlanetIndex, x: rx, y: ry, buffer: buffer)
    }
    
    
    private func drawArrakisZoom(_ buffer: PixelBuffer) {
        guard let starsSprite = starsSprite else {
            return
        }
        
        if contextBuffer.tag != 0x0006 {
            contextBuffer.clearBuffer()
            starsSprite.setPalette()
            starsSprite.drawFrame(2, x: 0, y: 0, buffer: contextBuffer)
            
            let arrakisFrameInfo = starsSprite.frame(at: 35) // 124 x 98
            let ax = Int16(320 - arrakisFrameInfo.width) / 2
            let ay = Int16(152 - arrakisFrameInfo.height) / 2
            starsSprite.drawFrame(35, x: ax, y: ay, buffer: contextBuffer)

            contextBuffer.tag = 0x0006
        }

        var fx: SpriteEffect {
            if currentTime >= duration - 0.5 {
                return .zoom(start: duration - 0.5, duration: 0.5, current: currentTime, from: DuneRect.fullScreen, to: DuneRect(140, 66, 40, 19))
            } else {
                return .none
            }
        }
        
        contextBuffer.render(to: buffer, effect: fx)
    }
}
