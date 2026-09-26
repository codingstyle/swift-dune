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
    /// The flat map: the eye frame with the planet (ICONES 6, 0x0D).
    case map
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
    // The first playable palace room supports all four exits.  Keeping the
    // left arrow in the initial state also avoids making a real exit appear
    // disabled before the room graph has been queried.
    private var directions: UIDirection = .all
    private var menuItems: [UInt16] = []
    private var menuCaptions: [String]? = nil
    private var menuGreyed: [Bool]? = nil
    private var dayNumber = 1
    private var phase: GamePhase = .dawn
    
    private var commands: Sentence?
    private var font: GameFont?
    
    private let menuRect = DuneRect(92, 159, 136, 40)
    private var menuItemBackgroundRect = DuneRect(93, 159, 134, 7)
    private var menuItemTextRect = DuneRect(97, 159, 120, 8)
  
    private let dayTextRect = DuneRect(7, 189, 22, 10)
    
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
          case .map:
            uiSprite.drawFrame(6, x: 0, y: 152, buffer: buffer)
            uiSprite.drawFrame(0x0D, x: 22, y: 161, buffer: buffer)
        }
      
        // Companion buttons belong to the normal room HUD only.  The DOS
        // book and map/globe friezes replace this area with their own panel;
        // drawing the room buttons there leaves two stray squares over the
        // left-bottom corner.
        if leftPanel == .bookClosed {
            // Companion slots ds:1152/1153 (record byte 14); ICONES 0x41 + id,
            // 64 = empty box.
            let slots = [World.shared.b(0x1152), World.shared.b(0x1153)]
            uiSprite.drawFrame(slots[0] == 0xFF ? 64 : 0x41 + UInt16(slots[0]), x: 35, y: 182, buffer: buffer)
            uiSprite.drawFrame(slots[1] == 0xFF ? 64 : 0x41 + UInt16(slots[1]), x: 58, y: 182, buffer: buffer)
        }

        // Right part
        switch rightPanel {
          case .mapDirections:
            // The flat map's arrows (seg000:d792 frieze; ScummVM drawPanelExtras).
            uiSprite.drawFrame(41, x: 266, y: 171, buffer: buffer)
            uiSprite.drawFrame(37, x: 267, y: 162, buffer: buffer)
            uiSprite.drawFrame(38, x: 285, y: 171, buffer: buffer)
            uiSprite.drawFrame(39, x: 267, y: 184, buffer: buffer)
            uiSprite.drawFrame(40, x: 254, y: 171, buffer: buffer)
            uiSprite.drawFrame(53, x: 266, y: 171, buffer: buffer)
          case .roomDirections:
            uiSprite.drawFrame(33, x: 255, y: 162, buffer: buffer)
            uiSprite.drawFrame(36, x: 269, y: 173, buffer: buffer)
            
            if directions.contains(.up) {
              uiSprite.drawFrame(29, x: 269, y: 162, buffer: buffer)
            }

            if directions.contains(.down) {
              uiSprite.drawFrame(31, x: 269, y: 181, buffer: buffer)
            }

            if directions.contains(.left) {
              uiSprite.drawFrame(32, x: 255, y: 172, buffer: buffer)
            }

            if directions.contains(.right) {
              uiSprite.drawFrame(30, x: 284, y: 172, buffer: buffer)
            }
          case .rect:
            break
        }
      
        renderMenus(buffer)
    }
  
  
    private static let sunPositions: [(x: Int16, y: Int16)?] = [
        (6, 187), (6, 186), (6, 185), (7, 183), (9, 182), (10, 181), (13, 181), (16, 181),
        (18, 182), (20, 183), (20, 185), (20, 186), (20, 187), nil, nil, nil
    ]
    private static let moonPositions: [(x: Int16, y: Int16)?] = [
        (25, 186), (26, 188), nil, nil, nil, nil, nil, nil,
        nil, nil, nil, (8, 188), (9, 186), (12, 183), (17, 182), (23, 183)
    ]


    private func renderTimeAndDay(_ buffer: PixelBuffer) {
        guard let uiSprite = uiSprite,
              let font = font else {
            return
        }
      
        font.paletteIndex = lightColorIndex
        font.render(String(dayNumber), rect: dayTextRect, buffer: buffer, alignment: .center, style: .small)
      
        // Sun (ICONES 0x4A) and moon (0x4B) positions for each of the 16
        // periods of a day: the table at ds:1E7E (ScummVM panel.cpp).
        let period = World.shared.hour
        if let sun = UI.sunPositions[period] {
            uiSprite.drawFrame(0x4A, x: sun.x, y: sun.y, buffer: buffer)
        }
        if let moon = UI.moonPositions[period] {
            uiSprite.drawFrame(0x4B, x: moon.x, y: moon.y, buffer: buffer)
        }
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

            let greyed = menuGreyed?.indices.contains(i) == true && menuGreyed![i]
            if i == selectedMenuIndex && !greyed && i < menuItems.count {
                Primitives.fillRect(menuItemBackgroundRect, 250, buffer, isOffset: false)
            }

            if i < menuItems.count {
                let sentence = menuCaptions?.indices.contains(i) == true
                    ? menuCaptions![i]
                    : commands.sentence(at: menuItems[i])
                font.paletteIndex = greyed ? 246 : i == selectedMenuIndex ? darkColorIndex : lightColorIndex
                let row = font.fit(sentence, width: Int(menuItemTextRect.width) - 2, style: .small)
                font.render(row, rect: menuItemTextRect, buffer: buffer, style: .small)
            }

            i += 1
        }
    }
    
    
    func onUIEvent(_ e: UIStateEventData) {
        self.menuItems = e.items
        self.menuCaptions = e.captions
        self.menuGreyed = e.greyed
        self.leftPanel = e.leftPanel
        self.rightPanel = e.rightPanel
        self.directions = e.directions
        self.dayNumber = e.day
        self.phase = e.phase
    }
}


struct UIStateEventData {
    var leftPanel: UILeftPanel
    var rightPanel: UIRightPanel
    var items: [UInt16]
    var directions: UIDirection = .all
    var day: Int = 1
    var phase: GamePhase = .dawn
    var captions: [String]? = nil
    /// Greyed rows: drawn in colour 246 (dark + 3), not selectable, no
    /// highlight (Panel::setRowDisabled in the ScummVM engine).
    var greyed: [Bool]? = nil
}


extension EventManager {
    static let uiStateChangedEvent = DuneEvent<UIStateEventData>()
}
