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
    
    private var flags: UInt16 = UIFlags.leftPanelGlobe.rawValue
    private var menuItems: [UInt16] = []
    
    private var commands: Sentence?
    private var font: GameFont?
    
    private let menuRect = DuneRect(92, 159, 136, 40)
    private var menuItemBackgroundRect = DuneRect(93, 159, 134, 7)
    private var menuItemTextRect = DuneRect(97, 159, 120, 8)
    
    // Colors for text and background
    private let lightColorIndex: UInt8 = 250
    private let darkColorIndex: UInt8 = 243

    init() {
        super.init("UI")
    }
    
    override func onEnable() {
        engine.addEventObserver(self)
        uiSprite = Sprite("ICONES.HSQ")
        commands = Sentence(.command)
        font = GameFont()
    }
    
    
    override func onDisable() {
        uiSprite = nil
        engine.removeEventObserver(self)
    }
    
    
    override func render(_ buffer: PixelBuffer) {
        guard let uiSprite = uiSprite else {
            return
        }
                
        // Left part
        if flags & UIFlags.leftPanelBookClosed.rawValue != 0x0 {
            uiSprite.drawFrame(0, x: 0, y: 152, buffer: buffer)
        } else if flags & UIFlags.leftPanelBookOpen.rawValue != 0x0 {
            uiSprite.drawFrame(9, x: 0, y: 152, buffer: buffer)
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
        
        // Head
        // let headState = 16 /* 16-25 */
        uiSprite.drawFrame(25, x: 150, y: 137, buffer: buffer)
        uiSprite.drawFrame(12, x: 2, y: 154, buffer: buffer)
        uiSprite.drawFrame(12, x: 253, y: 154, buffer: buffer)

        // Right panel
        uiSprite.drawFrame(3, x: 228, y: 152, buffer: buffer)
        
        // Directions
        if flags & UIFlags.rightPanelRoomDirections.rawValue != 0x0 {
            uiSprite.drawFrame(33, x: 255, y: 162, buffer: buffer)
        }

        renderMenus(buffer)
    }
    
    
    private func renderMenus(_ buffer: PixelBuffer) {
        guard let uiSprite = uiSprite,
            let commands = commands,
            let font = font else {
            return
        }
        
        // Commands list
        Primitives.fillRect(menuRect, 250, buffer, isOffset: false)
        
        // Menu item captions
        var i: Int = 0
        var selectedMenuIndex: Int = -1
        
        if menuRect.contains(engine.mouse.coordinates) {
            selectedMenuIndex = Math.clamp(Int((engine.mouse.coordinates.y - 159) / 8), 0, 5)
        }
        
        menuItemBackgroundRect.y = 159
        menuItemTextRect.y = 159
        
        while i < 5 {
            let y = 159 + Int16(8 * i)
            menuItemBackgroundRect.y = y + 1
            menuItemTextRect.y = y + 1

            uiSprite.drawFrame(27, x: 92, y: y, buffer: buffer)

            if i == selectedMenuIndex {
                Primitives.fillRect(menuItemBackgroundRect, 250, buffer, isOffset: false)
            }

            if i < menuItems.count {
                let sentence = commands.sentence(at: menuItems[i])
                font.paletteIndex = i == selectedMenuIndex ? darkColorIndex : lightColorIndex
                font.render(sentence, rect: menuItemTextRect, buffer: buffer, style: .small)
            }

            i += 1
        }
    }
    
    
    func onEvent(_ source: String, _ e: DuneEvent) {
        switch e {
        case .uiMenuChanged(let items):
            self.menuItems = items
        case .uiFlagsChanged(let flags):
            self.flags = flags
        default:
            break
        }
    }
}
