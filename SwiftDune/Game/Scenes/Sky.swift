//
//  Sky.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 08/03/2024.
//

import Foundation

final class Sky: DuneNode {
    private var contextBuffer = PixelBuffer(width: 320, height: 152)
    private var skySprite: Sprite?
    
 
    init() {
        super.init("Sky")
    }
    
    
    override func onEnable() {
        skySprite = Sprite("SKY.HSQ")
    }
    
    
    override func onDisable() {
        skySprite = nil
    }
    
    
    override func render(_ buffer: PixelBuffer) {
        guard let skySprite = skySprite else {
            return
        }
        
        skySprite.setAlternatePalette(3)

        for x: Int16 in stride(from: 0, to: 320, by: 40) {
            skySprite.drawFrame(0, x: x, y: 0, buffer: contextBuffer)
            skySprite.drawFrame(1, x: x, y: 20, buffer: contextBuffer)
            skySprite.drawFrame(2, x: x, y: 40, buffer: contextBuffer)
            skySprite.drawFrame(3, x: x, y: 60, buffer: contextBuffer)
        }
    }
}
