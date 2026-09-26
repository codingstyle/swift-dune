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

enum FreskMenuAction {
    case handled
    case close
    case quit
    /// A save was loaded: show wherever it puts Paul.
    case loaded
    case restart
}

private enum FreskMenuMode {
    case globe
    case results
    case quitConfirmation
    case save
    case load
    case options
}

final class Fresk: DuneNode {
    private var contextBuffer = PixelBuffer(width: 320, height: 152)
    
    private var freskSprite: Sprite?
    private var globe: Globe?
    private var font: GameFont?
    private var commands: Sentence?
    private var menuMode: FreskMenuMode = .globe
    
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
        globe?.beginInteractiveControl()
        font = GameFont()
        commands = Sentence(.command, language: .english)
        menuMode = .globe
    }
    
    
    override func onDisable() {
        freskSprite = nil
        globe = nil
        font = nil
        commands = nil
    }
    
    
    override func update(_ elapsedTime: TimeInterval) {
        currentTime += elapsedTime
        
        guard let globe = globe else {
            return
        }
        
        globe.update(currentTime)
        publishMenuState(recomputeRows: false)
    }


    override func onKey(_ key: DuneKeyEvent) {
        guard let globe = globe else { return }

        switch key.specialKey {
        case .keyLeft:
            globe.move(.left)
        case .keyRight:
            globe.move(.right)
        case .keyUp:
            globe.move(.up)
        case .keyDown:
            globe.move(.down)
        case .none, .keyReturn, .keyDelete, .keyEscape:
            break
        }
    }


    /// Save/load rows: COMMAND 258-261 ("Log 1: DAY  0 / 12.00 a.m.", ...)
    /// with the slot's day and the period's label from COMMAND 266 (sixteen
    /// 10-character labels), then EXIT GLOBE.
    private var slotCaptions: [String] {
        let labels = GameText.shared.command(266)
        var captions: [String] = []
        for slot in 0..<4 {
            var caption = GameText.shared.command(258 + slot)
            if slot < 2, let time = SaveGame.shared.slotTime(slot) {
                let period = Int(time & 15)
                let start = labels.index(labels.startIndex, offsetBy: min(10 * period, max(0, labels.count - 10)))
                let label = labels.count >= 10 ? String(labels[start...].prefix(10)).trimmingCharacters(in: .whitespaces) : ""
                caption = "Log \(slot + 1): DAY \(String(format: "%2d", time >> 4)) / \(label)"
            } else if SaveGame.shared.slotTime(slot) == nil {
                caption += " -"
            }
            captions.append(caption)
        }
        captions.append(statusCaption ?? GameText.shared.command(170))
        return captions
    }
    private var statusCaption: String?


    /// Save/load row texts, computed when the menu changes (they read the
    /// slot files), not every frame.
    private var rowCaptions: [String]?

    private func publishMenuState(recomputeRows: Bool = true) {
        if recomputeRows {
            rowCaptions = menuMode == .save || menuMode == .load ? slotCaptions : nil
        }
        EventManager.uiStateChangedEvent.notify(UIStateEventData(
            leftPanel: .globe,
            rightPanel: .rect,
            items: menuItems,
            day: GameState.shared.day,
            phase: GameState.shared.phase,
            captions: rowCaptions
        ))
    }


    func showResults() {
        menuMode = .results
        publishMenuState()
    }
    
    
    override func render(_ buffer: PixelBuffer) {
        guard let freskSprite = freskSprite,
              let globe = globe else {
            return
        }
        
        freskSprite.setPalette()

        if menuMode == .results {
            renderResults(buffer)
            return
        }
        
        Primitives.fillRect(DuneRect(0, 0, 319, 152), 241, buffer, isOffset: false)
        
        renderHousesPanels(buffer)
        
        freskSprite.drawFrame(2, x: 91, y: 20, buffer: buffer)
        globe.render(buffer: buffer)
    }


    private var menuItems: [UInt16] {
        switch menuMode {
        case .globe:
            return menuItemsGlobe
        case .results:
            return menuItemsStats
        case .quitConfirmation:
            return [171, 172]
        case .save, .load:
            return [258, 259, 260, 261, 170]
        case .options:
            // MUSIC OFF / MUSIC ON (GAME RELATIVE), RESTART, EXIT GAME, EXIT GLOBE
            return [engine.audioPlayer.musicMuted ? 254 : 257, 173, 174, 170]
        }
    }


    private func renderResults(_ buffer: PixelBuffer) {
        guard let freskSprite = freskSprite,
              let font = font,
              let commands = commands else {
            return
        }

        // The DOS results callback slides the FRESK decorations apart and
        // paints these command strings over the live area-control view. Keep
        // the same source strings and layout while the full gauge animation
        // is still being ported.
        Primitives.fillRect(DuneRect(0, 0, 319, 152), 241, buffer, isOffset: false)
        freskSprite.drawFrame(0, x: 0, y: 0, buffer: buffer)
        freskSprite.drawFrame(1, x: 214, y: 0, buffer: buffer)

        font.paletteIndex = 250
        font.render(commands.sentence(at: 181), rect: DuneRect(72, 4, 176, 12), buffer: buffer, alignment: .center, style: .small)
        font.render(commands.sentence(at: 182), rect: DuneRect(72, 18, 176, 12), buffer: buffer, alignment: .center, style: .small)
        font.render(commands.sentence(at: 185), rect: DuneRect(48, 39, 224, 12), buffer: buffer, alignment: .center, style: .small)
        font.render(commands.sentence(at: 186), rect: DuneRect(58, 53, 96, 12), buffer: buffer, alignment: .center, style: .small)
        font.render(commands.sentence(at: 187), rect: DuneRect(166, 53, 96, 12), buffer: buffer, alignment: .center, style: .small)
        font.render(commands.sentence(at: 188), rect: DuneRect(48, 72, 224, 12), buffer: buffer, alignment: .center, style: .small)
        font.render(commands.sentence(at: 189), rect: DuneRect(58, 86, 96, 12), buffer: buffer, alignment: .center, style: .small)
        font.render(commands.sentence(at: 190), rect: DuneRect(166, 86, 96, 12), buffer: buffer, alignment: .center, style: .small)
        font.render(commands.sentence(at: 191), rect: DuneRect(48, 105, 224, 12), buffer: buffer, alignment: .center, style: .small)

        // Keep the source command strings above, but expose the live state
        // that the original results screen is driven by. This is intentionally
        // raw: the location table and spice bytes are decoded, while troop
        // population is not yet available from the save record.
        font.paletteIndex = 250
        let state = GameState.shared
        font.render("DAY \(state.day) \(state.phase.title)",
                    rect: DuneRect(10, 2, 56, 10), buffer: buffer,
                    alignment: .left, style: .small)
        font.render("LOC \(state.currentLocation) SPICE \(state.spiceDensity)",
                    rect: DuneRect(10, 16, 110, 10), buffer: buffer,
                    alignment: .left, style: .small)
        font.render("ORDER \(state.troopOrder.title)",
                    rect: DuneRect(10, 30, 110, 10), buffer: buffer,
                    alignment: .left, style: .small)
        font.render("ROLE \(state.troopOccupation.title)",
                    rect: DuneRect(10, 58, 110, 10), buffer: buffer,
                    alignment: .left, style: .small)
        font.render(state.milestone.rawValue,
                    rect: DuneRect(10, 44, 110, 10), buffer: buffer,
                    alignment: .left, style: .small)

    }


    override func onClick(_ event: DuneMouseClickEvent) {
        guard let globe = globe else {
            return
        }

        let point = event.point
        guard point.y >= 158 && point.y < 200 else {
            return
        }

        // Keep these hit regions aligned with dune-rust's wasm_globe click()
        // implementation and with the ICONES.HSQ positions rendered by UI.
        if point.x >= 38 && point.x < 54 && point.y >= 159 && point.y < 172 {
            globe.move(.up)
        } else if point.x >= 54 && point.x < 72 && point.y >= 168 && point.y < 185 {
            globe.move(.right)
        } else if point.x >= 38 && point.x < 54 && point.y >= 183 && point.y < 200 {
            globe.move(.down)
        } else if point.x >= 20 && point.x < 37 && point.y >= 168 && point.y < 185 {
            globe.move(.left)
        } else if point.x >= 36 && point.x < 57 && point.y >= 172 && point.y < 182 {
            globe.center()
        }
    }


    func menuAction(for event: DuneMouseClickEvent) -> FreskMenuAction? {
        let point = event.point
        guard point.x >= 92 && point.x < 228 && point.y >= 159 && point.y < 199 else {
            return nil
        }

        let index = Int((point.y - 159) / 8)
        func show(_ mode: FreskMenuMode) -> FreskMenuAction {
            menuMode = mode
            statusCaption = nil
            publishMenuState()
            return .handled
        }
        switch menuMode {
        case .globe, .results:
            switch index {
            case 0: return .close
            case 1: return show(menuMode == .globe ? .results : .globe)
            case 2: return show(.save)
            case 3: return show(.load)
            case 4: return show(.options)
            default: return .handled
            }
        case .save:
            if index == 4 { return .close }
            // SAVE SUCCESSFUL (262) or *** SAVE ERROR (263) in the last row.
            statusCaption = GameText.shared.command(SaveGame.shared.save(index) ? 262 : 263)
            publishMenuState()
            return .handled
        case .load:
            if index == 4 { return .close }
            return SaveGame.shared.load(index) ? .loaded : .handled
        case .options:
            switch index {
            case 0:
                engine.audioPlayer.musicMuted.toggle()
                publishMenuState()
                return .handled
            case 1: return .restart
            case 2: return show(.quitConfirmation)
            case 3: return .close
            default: return .handled
            }
        case .quitConfirmation:
            switch index {
            case 0:
                return .quit
            case 1:
                menuMode = .globe
                publishMenuState()
                return .handled
            default:
                return .handled
            }
        }
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
