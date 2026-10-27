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
    case globeDirections
}

enum UIRightPanel: Int {
    case mapDirections = 1
    case roomDirections
    case rect
}


struct SpritePosition {
    var spriteIndex: UInt16
    var pt: DunePoint
  
    init(_ spriteIndex: UInt16, _ pt: DunePoint) {
        self.spriteIndex = spriteIndex
        self.pt = pt
    }
}


final class UI: DuneNode {
    private var uiSprite: Sprite?
    private var characterSprite: Sprite?
    private var palacePlanSprite: Sprite?
    private var palacePlanVisible: Bool = false
    
    private var leftPanel: UILeftPanel = .bookClosed
    private var rightPanel: UIRightPanel = .roomDirections
    private var directions: UIDirection = [.up, .down, .right]

    private let compassUpRect = DuneRect(264, 160, 18, 12)
    private let compassDownRect = DuneRect(264, 180, 18, 12)
    private let compassLeftRect = DuneRect(250, 170, 16, 14)
    private let compassRightRect = DuneRect(280, 170, 16, 14)
    private let mapUpRect = DuneRect(267, 162, 17, 9)
    private let mapRightRect = DuneRect(285, 171, 12, 13)
    private let mapDownRect = DuneRect(267, 184, 17, 9)
    private let mapLeftRect = DuneRect(254, 171, 12, 13)
    private var commands: Sentence?
    private var font: GameFont?
    
    private let menuRect = DuneRect(92, 159, 136, 40)
    private var menuItemBackgroundRect = DuneRect(93, 159, 134, 7)
    private var menuItemTextRect = DuneRect(97, 159, 126, 8)
  
    private var rightCloseRect = DuneRect(255, 162, 40, 30)
  
    private let palacePlanButtonRect = DuneRect(269, 173, 9, 7)
    private let palacePlanPositions: [SpritePosition] = [
      SpritePosition(0, DunePoint(182, 12)),
      SpritePosition(3, DunePoint(266, 65)),
      SpritePosition(4, DunePoint(238, 65)),
      SpritePosition(5, DunePoint(193, 65))
    ]
    private let palacePlanOrigin = DunePoint(182, 12)
    // Offsets for DOS palace rooms 2...12, added to the plan origin.
    private let palacePlanRoomOffsets: [(UInt8, UInt8)] = [
      (29, 65), (85, 49), (29, 33), (57, 17), (57, 65),
      (29, 49), (1, 49), (29, 1), (29, 17), (57, 49), (1, 65)
    ]
    private let palacePlanRect = DuneRect(160, 0, 160, 116)
  
    private var headIndex: UInt16 = 26
    private var startHeadIndex: UInt16 = 26
    private var headAnimation: DuneAnimation<UInt16>?
  
    private var pageFlipAnimation: DuneAnimation<UInt16>?
    private var pageFlipStartIndex: UInt16 = 10
  
    private let bookRect = DuneRect(22, 152, 50, 26)
    private let bookLeftPageRect = DuneRect(13, 152, 30, 40)
    private let bookRightPageRect = DuneRect(33, 152, 120, 40)
  
    private let dayTextRect = DuneRect(7, 189, 22, 10)
    
    // Colors for text and background
    private let menuTextColor: UInt8 = 0xfa
    private let menuBackgroundColor: UInt8 = 0xf3
    private let menuGreyColor: UInt8 = 0xf5
  
    init() {
        super.init("UI")
    }
    
    override func onEnable() {
        uiSprite = Sprite("ICONES.HSQ")
        palacePlanSprite = Sprite("PALPLAN.HSQ")
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
        palacePlanSprite = nil
        palacePlanVisible = false
        
        EventManager.uiStateChangedEvent.removeListener(self)
    }
  
  
    override func update(_ elapsedTime: TimeInterval) {
        currentTime += elapsedTime

        if let headAnimation = headAnimation {
            if startHeadIndex == 26 {
                headIndex = startHeadIndex - headAnimation.interpolate(currentTime)
            } else {
                headIndex = startHeadIndex + headAnimation.interpolate(currentTime)
            }
            
            if headIndex == 16 && headIndex != startHeadIndex {
                EventManager.uiStateChangedEvent.notify(UIStateEventData(leftPanel: .bookOpen, rightPanel: .rect))
                self.headAnimation = nil
                startHeadIndex = headIndex
            } else if headIndex == 26 && headIndex != startHeadIndex {
                EventManager.uiStateChangedEvent.notify(UIStateEventData(leftPanel: .bookClosed, rightPanel: .roomDirections))
                EventManager.bookStateChangedEvent.notify(BookStateEventData(action: .close))
                self.headAnimation = nil
                startHeadIndex = headIndex
            }
        }
    }
    
    
    override func render(_ buffer: PixelBuffer) {
        guard let uiSprite = uiSprite else {
            return
        }
                
        // Block
        uiSprite.drawFrame(15, x: 126, y: 148, buffer: buffer)
        uiSprite.drawFrame(14, x: 92, y: 152, buffer: buffer)
        
        // Head
        uiSprite.drawFrame(headIndex, x: 150, y: 137, buffer: buffer)
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
            uiSprite.drawFrame(13, x: 22, y: 161, buffer: buffer)
            break
          case .globeDirections:
            uiSprite.drawFrame(6, x: 0, y: 152, buffer: buffer)
            uiSprite.drawFrame(13, x: 22, y: 161, buffer: buffer)
            uiSprite.drawFrame(49, x: 38, y: 159, buffer: buffer)
            uiSprite.drawFrame(50, x: 54, y: 168, buffer: buffer)
            uiSprite.drawFrame(51, x: 38, y: 183, buffer: buffer)
            uiSprite.drawFrame(52, x: 20, y: 168, buffer: buffer)
            uiSprite.drawFrame(53, x: 36, y: 172, buffer: buffer)
            break
        }
  
        // Book flip page animation
        if let pageFlipAnimation = pageFlipAnimation {
          let index = pageFlipStartIndex == 10 ?
            pageFlipStartIndex + pageFlipAnimation.interpolate(currentTime) :
            pageFlipStartIndex - pageFlipAnimation.interpolate(currentTime)
          uiSprite.drawFrame(index, x: 27, y: 158, buffer: buffer)
          
          if currentTime > pageFlipAnimation.endTime {
            self.pageFlipAnimation = nil
          }
        }
      
        // Characters
        if leftPanel == .bookClosed {
            uiSprite.drawFrame(64, x: 35, y: 182, buffer: buffer)
            uiSprite.drawFrame(64, x: 58, y: 182, buffer: buffer)
        }

        // Right part
        switch rightPanel {
          case .mapDirections:
            uiSprite.drawFrame(41, x: 266, y: 171, buffer: buffer)
            uiSprite.drawFrame(37, x: 267, y: 162, buffer: buffer)
            uiSprite.drawFrame(38, x: 285, y: 171, buffer: buffer)
            uiSprite.drawFrame(39, x: 267, y: 184, buffer: buffer)
            uiSprite.drawFrame(40, x: 254, y: 171, buffer: buffer)
            uiSprite.drawFrame(53, x: 266, y: 171, buffer: buffer)
          case .roomDirections:
            uiSprite.drawFrame(33, x: 255, y: 162, buffer: buffer)
            
            // Red dot
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
            uiSprite.drawFrame(41, x: 266, y: 171, buffer: buffer)
            break
        }
      
        renderMenus(buffer)
      
        if palacePlanVisible {
            renderPalacePlan(buffer)
        }
    }
  
  
    private func renderTimeAndDay(_ buffer: PixelBuffer) {
        guard let uiSprite = uiSprite,
              let font = font else {
            return
        }
      
        font.paletteIndex = menuTextColor
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

        let rows = Menus.shared.visibleRows()
        var hover = -1
        if engine.input.mouseEnabled && menuRect.contains(engine.input.coordinates) {
            hover = Int((engine.input.coordinates.y - menuRect.y) / 8)
        }

        Primitives.fillRect(menuRect, Int(menuBackgroundColor), buffer, isOffset: false)

        var i = 0
        while i < 5 {
            let y = menuRect.y + Int16(8 * i)
            menuItemBackgroundRect.y = y + 1
            menuItemTextRect.y = y + 1
            uiSprite.drawFrame(27, x: 92, y: y, buffer: buffer)

            let row = i < rows.count ? rows[i] : MenuRow(textId: 0, greyed: false, highlighted: false)
            let highlighted = row.highlighted || (hover == i && row.textId != 0 && !row.greyed)
            let background = highlighted && !row.greyed ? menuTextColor : menuBackgroundColor
            Primitives.fillRect(menuItemBackgroundRect, Int(background), buffer, isOffset: false)

            if row.textId != 0 {
                if row.greyed {
                    font.paletteIndex = menuGreyColor
                } else if highlighted {
                    font.paletteIndex = menuBackgroundColor
                } else {
                    font.paletteIndex = menuTextColor
                }
                let sentence = commands.sentence(at: row.textId)
                font.render(sentence, rect: menuItemTextRect, buffer: buffer, style: .small)
            }

            i += 1
        }
    }
  
  
    func renderPalacePlan(_ buffer: PixelBuffer) {
        guard let palacePlanSprite = palacePlanSprite else {
            return
        }

        Primitives.fillRect(palacePlanRect, 0xf1, buffer, isOffset: false)
        Primitives.drawNestedRect(palacePlanRect, 0xf7, buffer, isOffset: false)

        let iconCount = palacePlanIconCount()
        var i = 0
        while i < iconCount && i < palacePlanPositions.count {
            let icon = palacePlanPositions[i]
            palacePlanSprite.drawFrame(icon.spriteIndex, x: icon.pt.x, y: icon.pt.y, buffer: buffer)
            i += 1
        }

        drawPalacePlanPopulation(palacePlanSprite, buffer)
    }


    func closePalacePlan() {
        palacePlanVisible = false
    }


    /// Locked-door covers hide the sealed rooms, including the greenhouse.
    /// A new game draws all three. Phases 0x0c, 0x1c and 0x54 each drop one,
    /// from the end of the icon list, until the secret room is visible.
    private func palacePlanIconCount() -> Int {
        let phase = GameState.shared.gamePhase
        if phase >= 0x54 { return 1 }
        if phase >= 0x1c { return 2 }
        if phase >= 0x0c { return 3 }
        return 4
    }


    private func drawPalacePlanPopulation(_ sprite: Sprite, _ buffer: PixelBuffer) {
        var inRoom = [UInt8](repeating: 0, count: 12)
        var travelling = [UInt8](repeating: 0, count: 12)
        var player = [UInt8](repeating: 0, count: 12)

        let state = GameState.shared
        let appearanceHi = UInt8(truncatingIfNeeded: state.locationAppearance >> 8)
        for person in state.roomPersons {
            if UInt8(truncatingIfNeeded: person.locationAppearance >> 8) != appearanceHi {
                continue
            }
            if person.personIndex == 4 && state.gamePhase >= 0x15 && state.gamePhase < 0x20 {
                continue
            }
            let index = Int(person.locationAndRoom & 0xFF) - 1
            guard inRoom.indices.contains(index) else { continue }
            if person.flags.contains(.npcCompanion) {
                travelling[index] &+= 1
            } else {
                inRoom[index] &+= 1
            }
        }

        let currentRoom = Int(state.locationAndRoom & 0xFF)
        if (1...12).contains(currentRoom) {
            player[currentRoom - 1] &+= 1
        }

        var i = 0
        while i < palacePlanRoomOffsets.count {
            let offset = palacePlanRoomOffsets[i]
            var x = palacePlanOrigin.x + Int16(offset.0) + 3
            var y = palacePlanOrigin.y + Int16(offset.1) + 2
            drawPopulationDots(inRoom[i + 1], x: x, y: y, sprite: sprite, buffer: buffer)
            y += 7
            drawPopulationDots(travelling[i + 1], x: x, y: y, sprite: sprite, buffer: buffer)
            x += 9
            y -= 4
            if player[i + 1] != 0 {
                sprite.drawFrame(1, x: x, y: y, buffer: buffer)
            }
            i += 1
        }
    }


    private func drawPopulationDots(_ count: UInt8, x: Int16, y: Int16, sprite: Sprite, buffer: PixelBuffer) {
        let total = min(Int(count), 5)
        var dotX = x
        var n = 0
        while n < total {
            sprite.drawFrame(2, x: dotX, y: y, buffer: buffer)
            dotX += 4
            n += 1
        }
    }
    
    
    func onUIEvent(_ e: UIStateEventData) {
        if let leftPanel = e.leftPanel {
            self.leftPanel = leftPanel
        }
        
        if let rightPanel = e.rightPanel {
            self.rightPanel = rightPanel
        }

        if let directions = e.directions {
            self.directions = directions
        }

        if let palacePlanVisible = e.palacePlanVisible {
            self.palacePlanVisible = palacePlanVisible
        }
    }
  
  
    override func onClick(_ event: DuneClickEvent) {
        if rightPanel == .roomDirections {
            let direction: Int?
            if compassUpRect.contains(event.point) && directions.contains(.up) {
                direction = 1
            } else if compassRightRect.contains(event.point) && directions.contains(.right) {
                direction = 2
            } else if compassDownRect.contains(event.point) && directions.contains(.down) {
                direction = 3
            } else if compassLeftRect.contains(event.point) && directions.contains(.left) {
                direction = 4
            } else {
                direction = nil
            }
            if let direction {
                EventManager.navigationEvent.notify(NavigationEventData(direction: direction))
                return
            }
        }

        if rightPanel == .mapDirections {
            let direction: Int?
            if mapUpRect.contains(event.point) {
                direction = 1
            } else if mapRightRect.contains(event.point) {
                direction = 2
            } else if mapDownRect.contains(event.point) {
                direction = 3
            } else if mapLeftRect.contains(event.point) {
                direction = 4
            } else {
                direction = nil
            }
            if let direction {
                EventManager.navigationEvent.notify(NavigationEventData(direction: direction))
                return
            }
        }

        if leftPanel == .bookClosed && rightPanel == .roomDirections && palacePlanButtonRect.contains(event.point) {
            if palacePlanVisible {
                palacePlanVisible = false
                Menus.shared.pop()
            } else if canOpenPalacePlan() {
                palacePlanVisible = true
                Menus.shared.push(.done)
            }
        }
      
        if bookRect.contains(event.point) && leftPanel == .bookClosed {
            showBook()
        }
      
        if leftPanel == .bookOpen {
            if bookLeftPageRect.contains(event.point) {
                turnBookPage(.turnPageLeft)
            } else if bookRightPageRect.contains(event.point) {
                turnBookPage(.turnPageRight)
            }
        }
      
        if rightPanel == .rect && rightCloseRect.contains(event.point) {
            if leftPanel == .bookOpen {
                hideBook()
            }
        }
      
        if menuRect.contains(event.point) {
            let slot = Int((event.point.y - menuRect.y) / 8)
            guard let choice = Menus.shared.choose(slot: slot) else {
                return
            }
            if choice.handler == MenuHandler.closeBook && leftPanel == .bookOpen {
                hideBook()
            } else if choice.handler == MenuHandler.exitMenu && palacePlanVisible {
                palacePlanVisible = false
                Menus.shared.pop()
            }
            EventManager.menuChoiceEvent.notify(MenuChoiceEventData(choice: choice))
        }
    }
  
  
    private func canOpenPalacePlan() -> Bool {
        let room = GameState.shared.locationAndRoom
        return room >> 8 == 0x20 && room & 0xFF != 1
    }


    func showBook() {
        startHeadIndex = 26
        headAnimation = DuneAnimation(from: 0, to: 10, startTime: currentTime, endTime: currentTime + 0.5)
    }
  
  
    func hideBook() {
        startHeadIndex = 16
        headAnimation = DuneAnimation(from: 0, to: 10, startTime: currentTime, endTime: currentTime + 0.5)
    }
  
  
    func turnBookPage(_ direction: BookAction) {
        pageFlipAnimation = DuneAnimation(from: 0, to: 1, startTime: currentTime, endTime: currentTime + 0.3)
        pageFlipStartIndex = direction == .turnPageLeft ? 11 : 10
        EventManager.bookStateChangedEvent.notify(.init(action: direction))
    }
}


struct UIStateEventData {
    var leftPanel: UILeftPanel?
    var rightPanel: UIRightPanel?
    var directions: UIDirection?
    var palacePlanVisible: Bool?
}

struct NavigationEventData {
    var direction: Int
}


struct ShowMapEventData {
}

struct ShowFreskEventData {
}

extension EventManager {
    static let uiStateChangedEvent = DuneEvent<UIStateEventData>()
    static let navigationEvent = DuneEvent<NavigationEventData>()
    static let showMapEvent = DuneEvent<ShowMapEventData>()
    static let showFreskEvent = DuneEvent<ShowFreskEventData>()
}
