//
//  Sunrise.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 28/12/2023.
//

import Foundation


final class Sunrise: DuneNode {
    private var contextBuffer = PixelBuffer(width: 320, height: 152)
    
    private var currentPaletteIndex = -1
    private var currentPaletteStart = 3
    private var currentPaletteEnd = 3
    private var paletteSteps: [Int] = []
    private var paletteAnimation: DuneAnimation<Int>?

    private var mode: DuneLightMode = .sunrise

    private var sunriseSprite: Sprite?
    private var showFort = false
    private var showVillage = false
    
    init() {
        super.init("Sunrise")
    }
    
    
    override func onEnable() {
        sunriseSprite = Sprite("SUNRS.HSQ")
        sunriseSprite!.setPalette()

        paletteAnimation = DuneAnimation<Int>(
            from: mode == .sunrise ? 0 : 3,
            to: mode == .sunrise ? 2 : 6,
            startTime: 0.0,
            endTime: 3.0
        )
    }
    
    
    override func onDisable() {
        sunriseSprite = nil
        currentPaletteIndex = -1
        currentPaletteStart = 3
        currentPaletteEnd = 3
        currentTime = 0.0
        duration = 4.0
        showFort = false
        showVillage = false
        mode = .day
        paletteAnimation = nil
    }
    
    
    override func onParamsChange() {
        if let duration = params["duration"] {
            self.duration = duration as! TimeInterval
        }
        
        if let mode = params["mode"] {
            self.mode = mode as! DuneLightMode
        }

        if let fort = params["fort"] {
            self.showFort = fort as! Bool
        }

        if let village = params["village"] {
            self.showVillage = village as! Bool
        }
    }
    
    
    override func update(_ elapsedTime: TimeInterval) {
        currentTime += elapsedTime

        if mode == .day {
            currentPaletteIndex = 0
            paletteSteps = [ 2 ]
        } else {
            paletteSteps = mode == .sunrise ? [ 0, 1, 2 ] : [ 3, 4, 5 ]
            
            let index = Int(floor(currentTime))
            currentPaletteIndex = Math.clamp(index, 0, paletteSteps.count - 1)
        }
        
        // Update palette
        guard let sunriseSprite = sunriseSprite else {
            return
        }
        
        if currentPaletteIndex < paletteSteps.count - 1 && currentTime > 0.0 {
            let blendProgress = fmod(currentTime, 1.0)
            sunriseSprite.setAlternatePalette(paletteSteps[currentPaletteIndex + 1], paletteSteps[currentPaletteIndex], blend: blendProgress)
        } else {
            sunriseSprite.setAlternatePalette(paletteSteps[currentPaletteIndex])
        }
    }
    
    
    override func render(_ buffer: PixelBuffer) {
        guard let sunriseSprite = sunriseSprite else {
            return
        }

        if contextBuffer.tag != 0x0001 {
            contextBuffer.clearBuffer()
            drawDesertBackground(contextBuffer)
            contextBuffer.tag = 0x0001
        }
        
        contextBuffer.render(to: buffer, effect: .none)

        if showVillage {
            sunriseSprite.drawFrame(1, x: 84, y: 11, buffer: buffer)
        }
      
        if showFort {
            sunriseSprite.drawFrame(7, x: 19, y: 74, buffer: buffer)
        }
    }
    
    
    private func drawDesertBackground(_ buffer: PixelBuffer) {
        let sunriseSprite = sunriseSprite!
        
        sunriseSprite.drawFrame(2, x: 0, y: 0, buffer: buffer)
        sunriseSprite.drawFrame(3, x: 0, y: 25, buffer: buffer)
        sunriseSprite.drawFrame(4, x: 0, y: 50, buffer: buffer)
        sunriseSprite.drawFrame(5, x: 0, y: 74, buffer: buffer)
        sunriseSprite.drawFrame(6, x: 134, y: 92, buffer: buffer)
        sunriseSprite.drawFrame(0, x: 0, y: 102, buffer: buffer)
    }
}
