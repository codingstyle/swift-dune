//
//  UI.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 22/01/2024.
//

import Foundation

enum UIFlags: UInt16 {
    case leftPanelBookClosed = 1
    case leftPanelBookOpen = 2
    case leftPanelGlobe = 4
    case rightPanelMapDirections = 8
    case rightPanelRoomDirections = 16
    case rightPanelRect = 32
}


final class UI: DuneNode, DuneEventObserver {
    private var engine = DuneEngine.shared
    
    private var uiSprite: Sprite?
    private var paletteSprite: Sprite?
    
    private var flags: UInt16 = UIFlags.leftPanelGlobe.rawValue

    init() {
        super.init("UI")
    }
    
    override func onEnable() {
        engine.addEventObserver(self)
        uiSprite = engine.loadSprite("ICONES.HSQ")
        paletteSprite = engine.loadSprite("FRESK.HSQ")
    }
    
    
    override func onDisable() {
        uiSprite = nil
        paletteSprite = nil
        engine.removeEventObserver(self)
    }
    
    
    override func render(_ buffer: PixelBuffer) {
        guard let uiSprite = uiSprite,
              let paletteSprite = paletteSprite else {
            return
        }
        
        paletteSprite.setPalette()
                
        // Left part
        if flags & UIFlags.leftPanelBookClosed.rawValue != 0x0 {
            uiSprite.drawFrame(9, x: 0, y: 152, buffer: buffer)
        } else if flags & UIFlags.leftPanelBookOpen.rawValue != 0x0 {
            uiSprite.drawFrame(0, x: 0, y: 152, buffer: buffer)
        } else if flags & UIFlags.leftPanelGlobe.rawValue != 0x0 {
            uiSprite.drawFrame(6, x: 0, y: 152, buffer: buffer)
            
            // Globe nav arrows
            uiSprite.drawFrame(13, x: 22, y: 161, buffer: buffer)
            uiSprite.drawFrame(49, x: 38, y: 159, buffer: buffer)
            uiSprite.drawFrame(50, x: 54, y: 168, buffer: buffer)
            uiSprite.drawFrame(51, x: 38, y: 183, buffer: buffer)
            uiSprite.drawFrame(52, x: 20, y: 168, buffer: buffer)
            uiSprite.drawFrame(53, x: 36, y: 172, buffer: buffer)

            // Map mode button
            uiSprite.drawFrame(41, x: 266, y: 171, buffer: buffer)
        }

        // Block
        uiSprite.drawFrame(15, x: 126, y: 148, buffer: buffer)
        uiSprite.drawFrame(14, x: 92, y: 152, buffer: buffer)
        
        // Commands list
        uiSprite.drawFrame(27, x: 92, y: 159, buffer: buffer)
        uiSprite.drawFrame(27, x: 92, y: 167, buffer: buffer)
        uiSprite.drawFrame(27, x: 92, y: 175, buffer: buffer)
        uiSprite.drawFrame(27, x: 92, y: 183, buffer: buffer)
        uiSprite.drawFrame(27, x: 92, y: 191, buffer: buffer)

        // Head
        let headState = 16 /* 16-25 */
        uiSprite.drawFrame(25, x: 150, y: 137, buffer: buffer)
        uiSprite.drawFrame(12, x: 2, y: 154, buffer: buffer)
        uiSprite.drawFrame(12, x: 253, y: 154, buffer: buffer)

        // Right panel
        uiSprite.drawFrame(3, x: 228, y: 152, buffer: buffer)
        
        // Directions
        if flags & UIFlags.rightPanelRoomDirections.rawValue != 0x0 {
            uiSprite.drawFrame(33, x: 255, y: 162, buffer: buffer)
        }
    }
    
    func onEvent(_ source: String, _ e: DuneEvent) {
        
    }
}
