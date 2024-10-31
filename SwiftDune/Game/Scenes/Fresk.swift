//
//  Fresk.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 29/01/2024.
//

import Foundation

enum FreskPanelState {
    case closed
    case open
}

final class Fresk: DuneNode {
    private var contextBuffer = PixelBuffer(width: 320, height: 152)
    
    private var freskSprite: Sprite?
    private var globe: Globe?
    
    private var panelState: FreskPanelState = .closed {
        didSet {
            panelAnimation = DuneAnimation(
                from: Int16(0),
                to: Int16(100),
                startTime: currentTime,
                endTime: currentTime + 0.8
            )
        }
    }
    
    private let menuItemsGlobe: [UInt16] = [170, 164, 166, 167, 168]
    private let menuItemsStats: [UInt16] = [170, 165, 166, 167, 168]

    private var panelAnimation: DuneAnimation<Int16>?
    
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
        currentTime += elapsedTime
        
        guard let globe = globe else {
            return
        }
        
        globe.update(currentTime)

        engine.sendEvent(self, .uiMenuChanged(items: menuItemsGlobe))
    }
    
    
    override func render(_ buffer: PixelBuffer) {
        guard let freskSprite = freskSprite,
              let globe = globe else {
            return
        }
        
        freskSprite.setPalette()
        
        Primitives.fillRect(DuneRect(0, 0, 319, 152), 241, buffer, isOffset: false)
        
        renderHousesPanels(buffer)
        
        freskSprite.drawFrame(2, x: 91, y: 20, buffer: buffer)
        globe.render(buffer: buffer)
    }
    
    
    private func renderHousesPanels(_ buffer: PixelBuffer) {
        guard let freskSprite = freskSprite else {
            return
        }
        
        var animX: Int16 = 0
        
        if let panelAnimation = panelAnimation {
            animX = panelAnimation.interpolate(currentTime) * (panelState == .closed ? -1 : 1)
        }
        
        freskSprite.drawFrame(0, x: 0 + animX, y: 0, buffer: buffer)
        freskSprite.drawFrame(1, x: 214 - animX, y: 0, buffer: buffer)
    }
}
