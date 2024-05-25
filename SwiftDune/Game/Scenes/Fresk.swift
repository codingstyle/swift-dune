//
//  Fresk.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 29/01/2024.
//

import Foundation

final class Fresk: DuneNode {
    private var contextBuffer = PixelBuffer(width: 320, height: 152)
    
    private var freskSprite: Sprite?
    private var globe: Globe?
    
    private var currentTime: TimeInterval = 0.0
    private let engine = DuneEngine.shared
    
    init() {
        super.init("Fresk")
    }
    
    
    override func onEnable() {
        freskSprite = Sprite("FRESK.HSQ")
        globe = Globe()
    }
    
    
    override func onDisable() {
        freskSprite = nil
        globe = nil
    }
    
    
    override func update(_ elapsedTime: TimeInterval) {
        guard let globe = globe else {
            return
        }
        
        globe.update(elapsedTime)
    }
    
    
    override func render(_ buffer: PixelBuffer) {
        guard let freskSprite = freskSprite,
              let globe = globe else {
            return
        }
        
        freskSprite.setPalette()
        
        Primitives.fillRect(DuneRect(95, 0, 225, 152), 241, buffer, isOffset: false)
        
        freskSprite.drawFrame(0, x: 0, y: 0, buffer: buffer)
        freskSprite.drawFrame(1, x: 214, y: 0, buffer: buffer)
        freskSprite.drawFrame(2, x: 91, y: 20, buffer: buffer)
        
        globe.render(buffer: buffer)
    }
}
