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
    private var freskSprite: Sprite?
    private var iconesSprite: Sprite?
    private var globe: Globe?
    private var commands: Sentence?
    private var font: GameFont?

    private var panelOffset: Int16 = 0
    private var panelState: FreskPanelState = .closed {
        didSet {
            let target: Int16 = panelState == .open ? -100 : 0
            panelAnimation = DuneAnimation(
                from: panelOffset,
                to: target,
                startTime: currentTime,
                endTime: currentTime + 0.8
            )
        }
    }
    private var panelAnimation: DuneAnimation<Int16>?

    private var showingResults = false
    private var gaugeCurrent = [UInt8](repeating: 0, count: 6)
    private var gaugeTargets = [UInt8](repeating: 1, count: 6)
    private var trendGlyphs = [UInt8](repeating: 0, count: 6)
    private var previousValues = [UInt16](repeating: 0, count: 6)
    private var gaugeWait: TimeInterval = 0
    /// results_gauge_task fires every 0x0c ticks of the 200 Hz PIT.
    private let gaugeStepInterval: TimeInterval = 12.0 * 0.00499253

    private let tiltUpRect = DuneRect(38, 159, 16, 13)
    private let rotateEastRect = DuneRect(54, 168, 18, 17)
    private let tiltDownRect = DuneRect(38, 183, 16, 16)
    private let rotateWestRect = DuneRect(20, 168, 17, 17)
    private let centerRect = DuneRect(36, 172, 21, 10)
    private let mapRect = DuneRect(255, 162, 40, 30)
    private let rotationNudge: UInt16 = 5271
    private let gaugeAnchors = [(26, 62), (54, 62), (252, 54), (280, 54), (252, 125), (280, 125)]

    init() {
        super.init("Fresk")
    }


    override func handleNavigation(_ direction: Int) -> Bool {
        switch direction {
        case 1:
            tilt(by: 8)
        case 2:
            rotate(by: -Int16(rotationNudge))
        case 3:
            tilt(by: -8)
        case 4:
            rotate(by: Int16(rotationNudge))
        default:
            break
        }
        return true
    }


    override func onEnable() {
        engine.audioPlayer.playSong("WATER.HSQ")

        freskSprite = Sprite("FRESK.HSQ")
        globe = Globe()
        commands = Sentence(.command)
        font = GameFont()
        Menus.shared.show(.globe)
        EventManager.uiStateChangedEvent.notify(UIStateEventData(
            leftPanel: .globeDirections,
            rightPanel: .rect
        ))
        EventManager.menuChoiceEvent.addListener(self) { [weak self] event in
            self?.onMenuChoice(event.choice)
        }
    }


    override func onDisable() {
        EventManager.menuChoiceEvent.removeListener(self)
        freskSprite = nil
        iconesSprite = nil
        globe = nil
        commands = nil
        font = nil
        showingResults = false
        panelAnimation = nil
        panelOffset = 0
    }


    override func onClick(_ event: DuneClickEvent) {
        if mapRect.contains(event.point) {
            EventManager.showMapEvent.notify(ShowMapEventData())
            return
        }

        if tiltUpRect.contains(event.point) {
            tilt(by: 8)
        } else if rotateEastRect.contains(event.point) {
            rotate(by: -Int16(rotationNudge))
        } else if tiltDownRect.contains(event.point) {
            tilt(by: -8)
        } else if rotateWestRect.contains(event.point) {
            rotate(by: Int16(rotationNudge))
        } else if centerRect.contains(event.point) {
            let position = GameState.shared.getMapPosition()
            globe?.stepToward(rotation: position.x, tilt: position.lat)
        }
    }


    override func update(_ elapsedTime: TimeInterval) {
        currentTime += elapsedTime
        globe?.update(currentTime)

        if let panelAnimation {
            panelOffset = panelAnimation.interpolate(currentTime)
        }

        guard showingResults else { return }
      
        gaugeWait += elapsedTime
      
        while gaugeWait >= gaugeStepInterval {
            gaugeWait -= gaugeStepInterval
            stepGauges()
        }
    }


    override func render(_ buffer: PixelBuffer) {
        guard let freskSprite = freskSprite,
              let globe = globe else {
            return
        }

        freskSprite.setPalette()
        Primitives.fillRect(DuneRect(0, 0, 319, 152), 241, buffer, isOffset: false)
        freskSprite.drawFrame(2, x: 91, y: 20, buffer: buffer)
        globe.render(buffer: buffer)

        if showingResults {
            renderStatistics(buffer)
        }
        renderHousesPanels(freskSprite, buffer)
    }


    private func onMenuChoice(_ choice: MenuChoice) {
        guard choice.scenario == .globe else { return }
      
        switch choice.handler {
        case MenuHandler.seeResults:
            showResults()
        case MenuHandler.seeStandardVision:
            showStandardVision()
        default:
            break
        }
    }


    private func showResults() {
        guard !showingResults else { return }
      
        showingResults = true
        iconesSprite = Sprite("ICONES.HSQ")
        gaugeCurrent = [UInt8](repeating: 0, count: 6)
        gaugeWait = gaugeStepInterval
        refreshGaugeTargets()
        globe?.showsAreaControl = true
        panelState = .open
        applyGlobeMenu()
    }


    private func showStandardVision() {
        guard showingResults else { return }
      
        showingResults = false
        iconesSprite = nil
        globe?.showsAreaControl = false
        panelState = .closed
        applyGlobeMenu()
    }


    private func applyGlobeMenu() {
        let second = showingResults
            ? MenuRecord(textId: CommandId.standardVision, handler: MenuHandler.seeStandardVision)
            : MenuRecord(textId: CommandId.seeResults, handler: MenuHandler.seeResults)
        Menus.shared.setRecords(.globe, [
            MenuRecord(textId: CommandId.exitGlobe, handler: MenuHandler.exitGlobe),
            second,
            MenuRecord(textId: CommandId.saveGame, handler: 0xb28c),
            MenuRecord(textId: CommandId.loadGame, handler: 0xb29e),
            MenuRecord(textId: CommandId.optionsAndQuit, handler: 0x0e3e)
        ])
    }


    private func tilt(by delta: Int16) {
        if delta > 0 {
            globe?.move(.down, tiltStep: delta, rotationStep: 0)
        } else if delta < 0 {
            globe?.move(.up, tiltStep: -delta, rotationStep: 0)
        }
    }


    private func rotate(by delta: Int16) {
        let step = UInt16(abs(Int(delta)))
      
        if delta > 0 {
            globe?.move(.right, tiltStep: 0, rotationStep: step)
        } else if delta < 0 {
            globe?.move(.left, tiltStep: 0, rotationStep: step)
        }
    }


    private func renderHousesPanels(_ freskSprite: Sprite, _ buffer: PixelBuffer) {
        freskSprite.drawFrame(0, x: panelOffset, y: 0, buffer: buffer)
        freskSprite.drawFrame(1, x: 214 - panelOffset, y: 0, buffer: buffer)
    }


    private func renderStatistics(_ buffer: PixelBuffer) {
        guard let freskSprite, let font else { return }
        freskSprite.drawFrame(3, x: 11, y: 124, buffer: buffer)
        freskSprite.drawFrame(4, x: 11, y: 136, buffer: buffer)

        let state = GameState.shared
        let day = (state.gameTime &+ 3) >> 4 &+ 1
        let charisma = UInt16(state.charisma >> 1)
        drawStat(0xb5, x: 16, y: 6, color: 0xfd, style: .normal, number: day, ordinal: true, buffer: buffer)
        drawStat(0xb6, x: 216, y: 6, color: 0xfd, style: .normal, number: charisma, buffer: buffer)

        let numbered: [UInt16: (UInt16, Bool)] = [
            0xb7: (state.areaControlledByHarkonnen, false),
            0xb8: (state.areaControlledByAtreides, false),
            0xba: (state.harkonnenSpiceProduction, true),
            0xbb: (state.todaysSpiceProduction, true),
            0xbd: (state.harkonnenTroopPopulation, true),
            0xbe: (state.troopPopulation, true)
        ]
        let rows: [(UInt16, Int, Int, UInt8)] = [
            (0xb7, 20, 69, 0x3f),
            (0xb8, 48, 69, 0x25),
            (0xb9, 8, 80, 0xfb),
            (0xba, 240, 60, 0x3f),
            (0xbb, 272, 60, 0x25),
            (0xbc, 236, 71, 0xfb),
            (0xbd, 240, 131, 0x3f),
            (0xbe, 272, 131, 0x25),
            (0xbf, 236, 142, 0xfb),
            (0xa2, 35, 125, 0x25),
            (0xa3, 35, 139, 0x3f)
        ]
      
        for row in rows {
            let value = numbered[row.0]
      
            drawStat(
                row.0,
                x: row.1,
                y: row.2,
                color: row.3,
                style: .small,
                number: value?.0,
                timesTen: value?.1 ?? false,
                buffer: buffer
            )
        }

        renderGauges(font, buffer)
    }


    private func drawStat(
        _ id: UInt16,
        x: Int,
        y: Int,
        color: UInt8,
        style: FontSize,
        number: UInt16? = nil,
        timesTen: Bool = false,
        ordinal: Bool = false,
        buffer: PixelBuffer
    ) {
        guard let commands, let font else { return }
        let text: String
      
        if let number {
            text = commands.formattedSentence(at: id, value: number, timesTen: timesTen, ordinal: ordinal)
        } else {
            text = commands.sentence(at: id)
        }

        font.paletteIndex = color
      
        let lineHeight: UInt8 = style == .normal ? 9 : 7
        let width = UInt16(max(1, 320 - x))
        
        font.render(
            text,
            rect: DuneRect(Int16(x), Int16(y), width, lineHeight),
            buffer: buffer,
            alignment: .left,
            style: style
        )
    }


    private func renderGauges(_ font: GameFont, _ buffer: PixelBuffer) {
        guard let iconesSprite else { return }
        var index = 0
      
        while index < gaugeAnchors.count {
            let anchor = gaugeAnchors[index]
            let height = Int(min(gaugeCurrent[index], 0x1e))
            let bar = UInt16(0x37 + (index & 1))
            var row = 0
          
            while row < height {
                iconesSprite.drawFrame(bar, x: Int16(anchor.0), y: Int16(anchor.1 - row), buffer: buffer)
                row += 1
            }
          
            iconesSprite.drawFrame(0x39, x: Int16(anchor.0), y: Int16(anchor.1 - height - 10), buffer: buffer)
            
            if gaugeCurrent[index] == gaugeTargets[index], trendGlyphs[index] != 0 {
                font.paletteIndex = index & 1 == 0 ? 0x3f : 0x25
                font.drawGlyph(
                    trendGlyphs[index],
                    x: anchor.0 + 4,
                    y: anchor.1 - height - 10,
                    buffer: buffer,
                    style: .small
                )
            }
            
            index += 1
        }
    }


    private func refreshGaugeTargets() {
        GameState.shared.refreshControlledAreas()
        GameState.shared.refreshResultsPopulations()
      
        let state = GameState.shared
        let values = [
            state.areaControlledByHarkonnen,
            state.areaControlledByAtreides,
            state.harkonnenSpiceProduction,
            state.todaysSpiceProduction,
            state.harkonnenTroopPopulation,
            state.troopPopulation
        ]
      
        gaugeTargets = [
            UInt8(truncatingIfNeeded: (values[0] >> 1) &+ 1),
            UInt8(truncatingIfNeeded: (values[1] >> 1) &+ 1),
            UInt8(truncatingIfNeeded: (values[2] >> 4) &+ 1),
            UInt8(truncatingIfNeeded: (values[3] >> 4) &+ 1),
            UInt8(truncatingIfNeeded: (values[4] >> 8) &+ 1),
            UInt8(truncatingIfNeeded: (values[5] >> 8) &+ 1)
        ]
      
        var index = 0
      
        while index < values.count {
            let old = previousValues[index]
            let value = values[index]
            
            if value != old {
                trendGlyphs[index] = value < old ? 2 : 1
            }
          
            previousValues[index] = value
            index += 1
        }
    }


    private func stepGauges() {
        var index = 0
        while index < gaugeCurrent.count {
            if gaugeCurrent[index] < gaugeTargets[index] {
                gaugeCurrent[index] &+= 1
            } else if gaugeCurrent[index] > gaugeTargets[index] {
                gaugeCurrent[index] &-= 1
            }
            index += 1
        }
    }
}
