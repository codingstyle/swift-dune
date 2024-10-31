//
//  Credits.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 08/10/2023.
//

import Foundation
import AppKit
import SwiftUI


final class Credits: DuneNode {
    private var backgroundBuffer = PixelBuffer(width: 320, height: 152)
    private var contextBuffer = PixelBuffer(width: 320, height: 152)
    
    private var creditsSprite: Sprite?
    private var duneSprite: Sprite?
    private var sky: Sky?

    private var scrollY: Int16 = 152
    private var scrollAnimation: DuneAnimation<Int16>?
    
    // Frame index, X position, Y offset
    private let spritePositions = [
        [0, 134, 0],    // Dune title
        [1, 77, 30],
        [2, 126, 90],   // Designed by
        [3, 56, 120],
        [4, 86, 210],   // Directed by
        [5, 68, 270],   // Team manager
        [6, 104, 340],  // Graphics by
        [7, 166, 360],
        [8, 166, 380],
        [9, 75, 440],   // Programming by
        [10, 166, 460],
        [11, 48, 540],  // Music by
        [12, 64, 570],
        [13, 124, 585],
        [14, 86, 615],
        [15, 88, 625],
        [16, 96, 715],  // Producers
        [17, 166, 735],
        [18, 166, 755],
        [19, 67, 815],  // Original design
        [20, 166, 835],
        [21, 65, 915],  // Special advisor
        [22, 58, 995],  // Cover art work
        [23, 75, 1035], // Skies palette
        [24, 92, 1075], // Animations
        [25, 166, 1095],
        [26, 67, 1135], // Graphics tools
        [27, 55, 1175], // Sietch decorator
        [28, 113, 1255],// Testing
        [29, 166, 1275],
        [30, 166, 1295],
        [31, 166, 1315],
        [32, 166, 1335],
        [33, 66, 1375], // FR and DE version
        [34, 60, 1415],
        [35, 108, 1505],// Special thanks
        [36, 64, 1520],
        [37, 120, 1535],
        [38, 126, 1565],
        [39, 59, 1580],
        [40, 96, 1595],
        [41, 114, 1685],// Kyle MacLachlan
        [42, 74, 1700],
        [43, 6, 1790]   // Trademark
    ]
    
    
    init() {
        super.init("Credits")
    }


    override func onEnable() {
        duneSprite = Sprite("INTDS.HSQ")
        sky = Sky()
        creditsSprite = Sprite("CREDITS.HSQ")

        scrollAnimation = DuneAnimation<Int16>(from: 0, to: 1936, startTime: 2.0, endTime: 54.0)
    }
    
    
    override func onDisable() {
        creditsSprite = nil
        duneSprite = nil
        sky = nil
        scrollAnimation = nil
        scrollY = 152
        currentTime = 0
    }
    
    
    override func update(_ elapsedTime: TimeInterval) {
        currentTime += elapsedTime

        guard let scrollAnimation = scrollAnimation else {
            return
        }
        
        scrollY = 152 - scrollAnimation.interpolate(currentTime)
    }
    
    
    override func render(_ buffer: PixelBuffer) {
        guard let creditsSprite = creditsSprite,
              let duneSprite = duneSprite,
              let sky = sky else {
            return
        }
       
        if backgroundBuffer.tag != 0x0001 {
            sky.render(backgroundBuffer, type: .narrow)

            creditsSprite.setPalette()
            duneSprite.drawFrame(0, x: 0, y: 60, buffer: backgroundBuffer)
            backgroundBuffer.tag = 0x0001

            engine.palette.stash()
        }

        var fx: SpriteEffect {
            if currentTime < 2.0 {
                return .fadeIn(start: 0.0, duration: 2.0, current: currentTime)
            }
            
            return .none
        }
        
        backgroundBuffer.render(to: contextBuffer, effect: fx)
        
        // Blit credit sprites
        var i = 0
        
        while i < spritePositions.count {
            let el = spritePositions[i]
            creditsSprite.drawFrame(UInt16(el[0]), x: Int16(el[1]), y: scrollY + Int16(el[2]), buffer: contextBuffer)
            
            i += 1
        }
        
        contextBuffer.copyPixels(to: buffer, offset: 24 * buffer.width)
    }
}
