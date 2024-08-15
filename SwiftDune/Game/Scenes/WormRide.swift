//
//  Death.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 02/08/2024.
//

import Foundation

final class WormRide: DuneNode {
    private let engine = DuneEngine.shared
    
    private var contextBuffer = PixelBuffer(width: 320, height: 152)
    private var wormSprite: Sprite?
    private var sky: Sky?
    private var duration: TimeInterval = 10.0
    private var currentTime: TimeInterval = 0.0
    private var dayMode: DuneLightMode = .day
    
    init() {
        super.init("WormRide")
    }

    
    override func onEnable() {
        wormSprite = Sprite("VER.HSQ")
        sky = Sky()
    }
    
    
    override func onDisable() {
        wormSprite = nil
        sky = nil
        currentTime = 0.0
    }
    
    
    override func update(_ elapsedTime: TimeInterval) {
        currentTime += elapsedTime
    }
    
    
    override func render(_ buffer: PixelBuffer) {
        guard let wormSprite = wormSprite else {
            return
        }

        drawBackground(buffer)
        wormSprite.drawAnimation(0, buffer: buffer, time: currentTime, offset: .zero)
    }
    
    
    
    private func drawBackground(_ buffer: PixelBuffer) {
        if contextBuffer.tag == dayMode.asInt {
            contextBuffer.render(to: buffer, effect: .none)
            return
        }
        
        guard let sky = sky else {
            return
        }
        
        sky.lightMode = dayMode
        sky.render(contextBuffer)

        Primitives.fillRect(DuneRect(0, 78, 320, 74), 63, contextBuffer)
        
        contextBuffer.render(to: buffer, effect: .none)
        contextBuffer.tag = dayMode.asInt
    }
}
