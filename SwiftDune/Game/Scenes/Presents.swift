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

/*
func animation(is animTick: AnimationTimeRange) -> Bool {
  return currentTime >= animTick.start && currentTime <= animTick.end
}
*/

enum PresentsScreen {
    case virginPresents
    case cryoPresents
}


final class Presents: DuneNode {
    private var contextBuffer = PixelBuffer(width: 320, height: 152)
    private var introSprite: Sprite?
  
    private var screen: PresentsScreen = .virginPresents

    init() {
        super.init("Presents")
    }
    
    
    override func onEnable() {
        introSprite = Sprite("INTDS.HSQ")
    }

    
    override func onDisable() {
        introSprite = nil
        currentTime = 0.0
        screen = .virginPresents
        contextBuffer.tag = 0x0000
        contextBuffer.clearBuffer()
    }
  
  
    override func onParamsChange() {
        if let screenParam = params["screen"] {
            self.screen = screenParam as! PresentsScreen
        }
    }
    
    
    override func update(_ elapsedTime: TimeInterval) {
        currentTime += elapsedTime
    }
    
    
    override func render(_ buffer: PixelBuffer) {
        guard let introSprite = introSprite else {
            return
        }
        
        // "Virgin Games presents"
        if screen == .virginPresents {
            if contextBuffer.tag != 0x0001 {
                contextBuffer.clearBuffer()
                
                introSprite.setPalette()
                introSprite.drawFrame(6, x: 62, y: 58, buffer: contextBuffer)
                introSprite.drawFrame(7, x: 114, y: 90, buffer: contextBuffer)

                contextBuffer.tag = 0x0001
            }
            
            contextBuffer.render(to: buffer)
        }

        // "A production from Cryo Interactive Entertainment Systems"
        if screen == .cryoPresents {
            if contextBuffer.tag != 0x0001 {
                contextBuffer.clearBuffer()
                introSprite.setPalette()
                
                introSprite.drawFrame(8, x: 76, y: 43, buffer: contextBuffer)
                introSprite.drawFrame(9, x: 132, y: 71, buffer: contextBuffer)
                introSprite.drawFrame(10, x: 14, y: 96, buffer: contextBuffer)

                contextBuffer.tag = 0x0001
            }
            
            contextBuffer.render(to: buffer)
        }
    }
}
