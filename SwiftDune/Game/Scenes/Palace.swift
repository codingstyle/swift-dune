//
//  Palace.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 11/02/2024.
//

import Foundation

enum PalaceRoom: Int {
    case porch = 0
    case diningRoom = 1
    case bedroom = 2
    case bedroomEmpty = 3
    case armory = 4
    case command = 5
    case commandHalfLit = 6
    case commandFullLit = 7
    case suitRoomFull = 8
    case suitRoomEmpty = 9
    case balcony = 10
    case stairs = 11
    case corridor = 12
    case darkHall = 13
    case garden = 14
}

final class Palace: DuneNode {
    private var contextBuffer = PixelBuffer(width: 320, height: 152)
    
    private var palaceScenery: Scenery?
    private var sky: Sky?
    private var characterSprite: Sprite?
    
    private var currentRoom: PalaceRoom = .stairs
    private var gameRoomID: Int?
    private var salRoomIndex: Int?
    private var markers: Dictionary<Int, RoomCharacter> = [:]
    /// The place's room file: PALACE.SAL, VILG.SAL or HARK.SAL (sietches
    /// use the Sietch node). This node draws any place's rooms.
    private var salFile = "PALACE.SAL"
    /// Set by the game from World.isOutdoors; nil = the palace's own rule.
    private var outdoor: Bool?
    /// Sheet from the room code (World.sheet(for:)); nil = legacy ranges.
    private var sheet: String?
    /// Character numbers in the room; placed with World.markerAssignment.
    private var people: [Int]?
    /// A scripted scene's cast: written straight into the marker slots
    /// (opcode 00), marker j showing slot markers - 1 - j.
    private var cast: [Int]?
    private var character: DuneCharacter = .none
    private var zoomRect: DuneRect?
    private var dayMode: DuneLightMode = .day
    
    private var transitionIn: TransitionEffect = .none
    private var transitionOut: TransitionEffect = .none

    init() {
        super.init("Palace")
    }
    
    
    override func onEnable() {
        palaceScenery = Scenery(salFile)
        sky = Sky()
        
        engine.palette.clear()
        palaceScenery?.sheetOverride = sheet
        applyPeople()
        palaceScenery?.characters = markers
    }


    /// Puts `people` on the current room's markers the way the original
    /// does (last marker first, see World.markerAssignment).
    private func applyPeople() {
        guard let people = people, let scenery = palaceScenery, let sal = salRoomIndex,
              sal >= 0 && sal < scenery.rooms.count else {
            engine.logger.log(.debug, "applyPeople skipped: people \(String(describing: people)) scenery \(palaceScenery != nil) sal \(String(describing: salRoomIndex))")
            return
        }
        var assignment = World.shared.markerAssignment(people: people, markers: scenery.rooms[sal].markerCount)
        if let cast = cast {
            let markers = scenery.rooms[sal].markerCount
            assignment = [:]
            for j in 0..<markers {
                let slot = markers - 1 - j
                if slot < cast.count && cast[slot] != 0xFF { assignment[j] = cast[slot] }
            }
        }
        markers = assignment.compactMapValues { RoomCharacter(rawValue: World.persFrame($0)) }
        scenery.characters = markers
        engine.logger.log(.debug, "applyPeople sal \(sal) markers \(scenery.rooms[sal].markerCount) people \(people) -> \(assignment)")
    }
    
    
    override func onDisable() {
        palaceScenery = nil
        sky = nil
        characterSprite = nil
        
        markers = [:]
        salFile = "PALACE.SAL"
        outdoor = nil
        sheet = nil
        people = nil
        cast = nil
        character = .none
        currentRoom = .stairs
        gameRoomID = nil
        salRoomIndex = nil
        currentTime = 0.0
        contextBuffer.tag = 0x0000
        zoomRect = nil
        dayMode = .day
    }
    
    
    override func onParamsChange() {
        if let room = params["room"] {
            self.currentRoom = room as! PalaceRoom
            self.currentTime = 0.0
            self.contextBuffer.tag = 0x0000
        }

        if let gameRoomID = params["gameRoomID"] as? Int {
            self.gameRoomID = gameRoomID
            self.currentTime = 0.0
            self.contextBuffer.tag = 0x0000
        }
        if let salRoomIndex = params["salRoom"] as? Int {
            self.salRoomIndex = salRoomIndex
        }
        
        if let markers = params["markers"] {
            self.markers = markers as! Dictionary<Int, RoomCharacter>
            palaceScenery?.characters = self.markers
        }

        if let file = params["salFile"] as? String, file != salFile {
            salFile = file
            if palaceScenery != nil {
                palaceScenery = Scenery(file)
            }
            contextBuffer.tag = 0
        }
        if params.keys.contains("outdoor") {
            outdoor = params["outdoor"] as? Bool
        }

        if params.keys.contains("sheet") {
            self.sheet = params["sheet"] as? String
            palaceScenery?.sheetOverride = self.sheet
        }

        if let people = params["people"] as? [Int] {
            self.people = people
            cast = nil
            applyPeople()
        }

        if let cast = params["cast"] as? [Int] {
            self.cast = cast
            applyPeople()
        }

        if let duration = params["duration"] {
            self.duration = duration as! Double
        }
        
        if let character = params["character"] {
            self.character = character as! DuneCharacter
            characterSprite = Sprite(self.character.resourceName)
        } else if params["gameRoomID"] != nil {
            self.character = .none
            characterSprite = nil
        }
        
        if let zoom = params["zoom"] {
            self.zoomRect = zoom as? DuneRect
        }

        if let dayMode = params["dayMode"] {
            self.dayMode = dayMode as! DuneLightMode
        }
        
        if let transitionInParam = params["transitionIn"] {
            self.transitionIn = transitionInParam as! TransitionEffect
        }

        if let transitionOutParam = params["transitionOut"] {
            self.transitionOut = transitionOutParam as! TransitionEffect
        }
    }
    
    
    override func update(_ elapsedTime: TimeInterval) {
        currentTime += elapsedTime
        
        if duration != 0.0 && currentTime > duration {
            EventManager.nodeEndedEvent.notify(NodeEventData(self.name))
        }
    }
    
    
    override func render(_ buffer: PixelBuffer) {
        guard let palaceScenery = palaceScenery,
              let sky = sky else {
            return
        }
        
        let intermediateFrameBuffer = engine.intermediateFrameBuffer
        
        intermediateFrameBuffer.clearBuffer()
        buffer.clearBuffer()

        // TODO: improve this according to day time
        if currentRoom == .stairs && dayMode == .sunrise {
            let sunriseProgress = Math.clampf((currentTime - 2.0) / 3.0, 0.0, 1.0)
            sky.lightMode = .custom(index: 16, prevIndex: 3, blend: sunriseProgress)
        } else if gameRoomID != nil {
            sky.lightMode = GameState.shared.phase.lightMode
        } else {
            sky.lightMode = .day
        }

        var fx: SpriteEffect {
            if let zoomRect = zoomRect {
                return .zoom(start: 0, duration: 9999.0, current: currentTime, from: zoomRect, to: zoomRect)
            } else {
                return .none
            }
        }

        let roomIndex = salRoomIndex ?? currentRoom.rawValue
        let isGameplayExterior = outdoor ?? (gameRoomID == 1 || gameRoomID == 5)
        let inPalace = salFile == "PALACE.SAL"

        // Apply sky gradient with blue palette
        if isGameplayExterior || (gameRoomID == nil && (currentRoom == .porch || currentRoom == .balcony)) {
            // Cache per room and sky: re-draw when the period's sky changes.
            let tag = 0x0100 | UInt32(roomIndex) << 4 | sky.lightMode.asInt | (inPalace ? 0 : 0x1000)
            if contextBuffer.tag != tag {
                contextBuffer.clearBuffer()
                if gameRoomID != nil && inPalace && roomIndex == 11 {
                    // The palace front (SAL room 11) uses the large sky, 200 px.
                    sky.render(contextBuffer, width: 200, at: 0, type: .large, gameplayPalette: true)
                } else {
                    sky.render(contextBuffer, width: 320, at: 0, type: .narrow, gameplayPalette: true)
                }
                if !inPalace {
                    // Outside the palace the ground under the horizon is
                    // colour 190 (ScummVM composeView).
                    Primitives.fillRect(DuneRect(0, 78, 320, 74), 190, contextBuffer, isOffset: false)
                }
                palaceScenery.drawRoom(roomIndex, buffer: contextBuffer)
                contextBuffer.tag = tag
            }

            contextBuffer.render(to: intermediateFrameBuffer, effect: fx)
        } else if currentRoom == .stairs {
            sky.render(intermediateFrameBuffer, width: 200, at: 0, type: .large)
            palaceScenery.drawRoom(roomIndex, buffer: intermediateFrameBuffer)

            // Fade on palace
            if dayMode == .sunrise {
                if currentTime > 1.0 {
                    palaceScenery.setPalette(roomIndex)
                    engine.palette.stash()
                }

                let sunriseProgress = Math.clampf((currentTime - 2.0) / 3.0, 0.0, 1.0)
                Effects.fade(progress: sunriseProgress, startIndex: 112, endIndex: 127)

                if currentTime == 0.0 {
                    engine.palette.stash()
                }
            }
        } else {
            // Interior rooms have no exterior sky. PALACE.SAL already contains
            // the complete polygon/sprite command stream for these rooms.
            palaceScenery.drawRoom(roomIndex, buffer: intermediateFrameBuffer)
        }

        // Rust's room renderer builds a fresh palette for every frame. Keep
        // the Swift shared palette deterministic as well: opening the globe
        // or book must not leave its palette behind when the cached room is
        // shown again.
        palaceScenery.setSharedPalette()
        palaceScenery.setCharacterPalette()
        // DOS opens PERS.HSQ while drawing standing characters, then
        // re-applies the active room sheet. Keep the room palette last so
        // EQUI/BALCON/CORR rooms do not inherit colours from another room.
        palaceScenery.setPalette(roomIndex)
        // The sky is indexed data, so it must be the final palette writer for
        // the exterior background. BALCON.HSQ has its own alternate palette;
        // applying it after SKY.HSQ turns the blue sky into the purple/green
        // balcony seen after room changes.
        if gameRoomID == nil && (currentRoom == .porch || currentRoom == .balcony || currentRoom == .stairs) {
            sky.setPalette()
        } else if isGameplayExterior {
            // Outdoor sheets have no palette of their own for 128-222: they
            // use the sky's, for the current period (FINDINGS, room drawing).
            sky.setPalette(gameplayPalette: true)
        }
        
        if let characterSprite = characterSprite {
            characterSprite.setPalette()
            characterSprite.drawAnimation(0, buffer: intermediateFrameBuffer, time: currentTime)
        }
        
        var fxTransition: SpriteEffect {
            switch transitionOut {
            case .dissolveOut:
                return .dissolveOut(end: duration, duration: 0.3, current: currentTime)
            default:
                return .none
            }
        }

        intermediateFrameBuffer.render(to: buffer, effect: fxTransition)
    }
}
