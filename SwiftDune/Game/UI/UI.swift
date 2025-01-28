//
//  UI.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 22/01/2024.
//

import Foundation


struct UIDirection: OptionSet {
  public let rawValue: Int
  
  public init(rawValue: Int) {
    self.rawValue = rawValue
  }
  
  static let left = UIDirection(rawValue: 1 << 0)
  static let right = UIDirection(rawValue: 1 << 1)
  static let up = UIDirection(rawValue: 1 << 2)
  static let down = UIDirection(rawValue: 1 << 3)
  
  static let all: UIDirection = [.left, .right, .up, .down]
}

enum UILeftPanel: Int {
    case bookClosed = 1
    case bookOpen
    case globe
}

enum UIRightPanel: Int {
    case mapDirections = 1
    case roomDirections
    case rect
}


final class UI: DuneNode {
    private var uiSprite: Sprite?
    private var characterSprite: Sprite?
    
    private var leftPanel: UILeftPanel = .bookClosed
    private var rightPanel: UIRightPanel = .roomDirections
    private var directions: UIDirection = .all
    private var menuItems: [UInt16] = []
    
    private var commands: Sentence?
    private var font: GameFont?
    
    private let menuRect = DuneRect(92, 159, 136, 40)
    private var menuItemBackgroundRect = DuneRect(93, 159, 134, 7)
    private var menuItemTextRect = DuneRect(97, 159, 120, 8)
  
    private let dayTextRect = DuneRect(7, 188, 22, 10)
    
    // Colors for text and background
    private let lightColorIndex: UInt8 = 250
    private let darkColorIndex: UInt8 = 243

    init() {
        super.init("UI")
    }
    
    override func onEnable() {
        uiSprite = Sprite("ICONES.HSQ")
        characterSprite = Sprite("PERS.HSQ")
        characterSprite?.setPalette()
        commands = Sentence(.command)
        font = GameFont()
      
        EventManager.uiStateChangedEvent.addListener(self) { [weak self] state in
            guard let self = self else { return }
            self.onUIEvent(state)
        }
    }
    
    
    override func onDisable() {
        uiSprite = nil
        characterSprite = nil
      
        EventManager.uiStateChangedEvent.removeListener(self)
    }
    
    
    override func render(_ buffer: PixelBuffer) {
        guard let uiSprite = uiSprite else {
            return
        }
                
        // Block
        uiSprite.drawFrame(15, x: 126, y: 148, buffer: buffer)
        uiSprite.drawFrame(14, x: 92, y: 152, buffer: buffer)
        
        // Head
        // let headState = 16 /* 16-25 */
        uiSprite.drawFrame(26, x: 150, y: 137, buffer: buffer)
        uiSprite.drawFrame(12, x: 2, y: 154, buffer: buffer)
        uiSprite.drawFrame(12, x: 317, y: 154, buffer: buffer)
        
        // Right panel
        uiSprite.drawFrame(3, x: 228, y: 152, buffer: buffer)
      
        // Left part
        switch leftPanel {
          case .bookClosed:
            uiSprite.drawFrame(0, x: 0, y: 152, buffer: buffer)
            renderTimeAndDay(buffer)
            break
          case .bookOpen:
            uiSprite.drawFrame(9, x: 0, y: 152, buffer: buffer)
            break
          case .globe:
            uiSprite.drawFrame(6, x: 0, y: 152, buffer: buffer)
            
            // Globe nav arrows
            uiSprite.drawFrame(13, x: 22, y: 161, buffer: buffer)
            uiSprite.drawFrame(49, x: 38, y: 159, buffer: buffer)
            uiSprite.drawFrame(50, x: 54, y: 168, buffer: buffer)
            uiSprite.drawFrame(51, x: 38, y: 183, buffer: buffer)
            uiSprite.drawFrame(52, x: 20, y: 168, buffer: buffer)
            uiSprite.drawFrame(53, x: 36, y: 172, buffer: buffer)
            break
        }
      
        switch rightPanel {
          case .mapDirections:
            uiSprite.drawFrame(41, x: 266, y: 171, buffer: buffer)
          case .roomDirections:
            uiSprite.drawFrame(33, x: 255, y: 163, buffer: buffer)
            
            switch directions {
              case .up:
                uiSprite.drawFrame(42, x: 266, y: 171, buffer: buffer)
              case .down:
                uiSprite.drawFrame(43, x: 266, y: 171, buffer: buffer)
              case .left:
                uiSprite.drawFrame(44, x: 266, y: 171, buffer: buffer)
              case .right:
                uiSprite.drawFrame(45, x: 266, y: 171, buffer: buffer)
              default:
                break
            }
          case .rect:
            break
        }
      
        renderMenus(buffer)
    }
  
  
    private func renderTimeAndDay(_ buffer: PixelBuffer) {
        guard let uiSprite = uiSprite,
              let font = font else {
            return
        }
      
        font.paletteIndex = lightColorIndex
        font.render("1", rect: dayTextRect, buffer: buffer, alignment: .center, style: .small)
      
        uiSprite.drawFrame(74, x: 6, y: 184, buffer: buffer)
        //uiSprite.drawFrame(75, x: 8, y: 188, buffer: buffer)
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
    
    
    func onUIEvent(_ e: UIStateEventData) {
        self.menuItems = e.items
        self.leftPanel = e.leftPanel
        self.rightPanel = e.rightPanel
    }
}


struct UIStateEventData {
    var leftPanel: UILeftPanel
    var rightPanel: UIRightPanel
    var items: [UInt16]
}


extension EventManager {
    static let uiStateChangedEvent = DuneEvent<UIStateEventData>()
}
