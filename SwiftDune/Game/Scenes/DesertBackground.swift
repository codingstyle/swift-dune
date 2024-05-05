//
//  DesertBackground.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 08/04/2024.
//

import Foundation

final class DesertBackground: DuneNode {
    private var desertSprite: Sprite?
    private var skySprite: Sprite?
    
    
    init() {
        super.init("DesertBackground")
    }
    
    
    override func onEnable() {
        desertSprite = Sprite("INTDS.HSQ")
        skySprite = Sprite("SKY.HSQ")
    }
    
    
    override func onDisable() {
        desertSprite = nil
        skySprite = nil
    }
    

    override func render(_ buffer: PixelBuffer) {
        guard let desertSprite = desertSprite,
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
        desertSprite.setPalette()
        desertSprite.drawFrame(0, x: 0, y: 60, buffer: buffer)
    }
}
