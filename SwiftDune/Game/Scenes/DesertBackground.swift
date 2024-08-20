//
//  DesertBackground.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 08/04/2024.
//

import Foundation

final class DesertBackground: DuneNode {
    private let engine = DuneEngine.shared
    
    private var desertSprite: Sprite?
    private var sky: Sky?
    
    
    init() {
        super.init("DesertBackground")
    }
    
    
    override func onEnable() {
        desertSprite = Sprite("INTDS.HSQ")
        sky = Sky()
    }
    
    
    override func onDisable() {
        desertSprite = nil
        sky = nil
    }
    

    override func render(_ buffer: PixelBuffer) {
        guard let desertSprite = desertSprite,
              let sky = sky else {
            return
        }

        // Apply sky gradient with blue palette
        sky.lightMode = .day
        sky.render(buffer)

        // Desert background
        desertSprite.setPalette()
        desertSprite.drawFrame(0, x: 0, y: 60, buffer: buffer)
    }
}
