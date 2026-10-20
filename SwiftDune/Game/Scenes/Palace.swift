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
    case bedroom = 2 // DOS palace room 9: Paul's room, the one with the mirror
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
    
    private var roomIndex: Int = PalaceRoom.porch.rawValue
    private var currentRoom: PalaceRoom {
        PalaceRoom(rawValue: roomIndex) ?? .porch
    }
    private var markers: Dictionary<Int, RoomCharacter> = [:]
    private var character: DuneCharacter = .none
    private var zoomRect: DuneRect?
    private var dayMode: DuneLightMode = .day
    
    private var playMusic = true
    private var managesCommands = false
    private var showingMirror = false
    private var roomCharacters: [DuneRoomPerson] = []
    private var mirrorSprite: Sprite?
    private var paulSprite: Sprite?
    private var chaniSprite: Sprite?

    init() {
        super.init("Palace")
    }
    
    
    override func onEnable() {
        palaceScenery = Scenery("PALACE.SAL")
        sky = Sky()

        syncStandingCharacters()

        guard managesCommands else { return }
        EventManager.menuChoiceEvent.addListener(self) { [weak self] event in
            self?.onMenuChoice(event.choice)
        }
    }
    
    
    override func onDisable() {
        palaceScenery = nil
        sky = nil
        characterSprite = nil
        
        markers = [:]
        roomIndex = PalaceRoom.porch.rawValue
        currentTime = 0.0
        contextBuffer.tag = 0x0000
        zoomRect = nil
        dayMode = .day
        playMusic = true
        if managesCommands {
            GameState.shared.personsInRoom = 0
        }
        managesCommands = false
        showingMirror = false
        roomCharacters = []
        mirrorSprite = nil
        paulSprite = nil
        chaniSprite = nil
        EventManager.menuChoiceEvent.removeListener(self)
    }
    
    
    override func onParamsChange() {
        if let room = params["room"] as? Int {
            roomIndex = room
            contextBuffer.tag = 0
        } else if let room = params["room"] as? PalaceRoom {
            roomIndex = room.rawValue
            contextBuffer.tag = 0
        }
        
        if let markers = params["markers"] {
            self.markers = markers as! Dictionary<Int, RoomCharacter>
        }

        if let duration = params["duration"] {
            self.duration = duration as! Double
        }
        
        if let character = params["character"] {
            self.character = character as! DuneCharacter
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

        if let playMusicParam = params["playMusic"] {
            self.playMusic = playMusicParam as! Bool
        }

        if let commands = params["commands"] as? Bool {
            managesCommands = commands
        }

        guard managesCommands else { return }
        dismissMirror()
        updateRoomCommands()
    }
    
    
    override func update(_ elapsedTime: TimeInterval) {
        if playMusic && currentTime == 0.0 {
            let music = Music("ARRAKIS.HSQ", player: engine.audioPlayer)
            engine.audioPlayer.play(music)
        }
        
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

        if showingMirror {
            renderMirror(intermediateFrameBuffer)
            intermediateFrameBuffer.render(to: buffer, effect: .none)
            return
        }

        syncStandingCharacters()

        // TODO: improve this according to day time
        if currentRoom == .stairs && dayMode == .sunrise {
            let sunriseProgress = Math.clampf((currentTime - 2.0) / 3.0, 0.0, 1.0)
            sky.lightMode = .custom(index: 16, prevIndex: 3, blend: sunriseProgress)
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

        // Apply sky gradient with blue palette
        if currentRoom == .porch || currentRoom == .balcony {
            if contextBuffer.tag != 0x0001 {
                sky.render(contextBuffer, width: 320, at: 0, type: .narrow)
                palaceScenery.drawRoom(roomIndex, buffer: contextBuffer)
                contextBuffer.tag = 0x0001
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
            if contextBuffer.tag != 0x0001 {
                palaceScenery.drawRoom(roomIndex, buffer: contextBuffer)
                contextBuffer.tag = 0x0001
            }

            contextBuffer.render(to: intermediateFrameBuffer, effect: fx)
        }
        
        if let characterSprite = characterSprite {
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


    override func onClick(_ event: DuneClickEvent) {
        guard showingMirror, event.point.y < 152 else { return }
        lookAwayFromMirror()
    }


    override func handleNavigation(_ direction: Int) -> Bool {
        showingMirror
    }


    private func onMenuChoice(_ choice: MenuChoice) {
        switch choice.handler {
        case MenuHandler.lookAtMirror:
            lookAtMirror()
        case MenuHandler.lookAwayFromTheMirror:
            lookAwayFromMirror()
        case MenuHandler.exitMenu:
            if choice.scenario == .npcActions {
                Menus.shared.show(.command)
            }
        default:
            guard choice.scenario == .command,
                  let person = roomCharacters.first(where: { $0.handler == choice.handler }) else {
                return
            }
            showCharacterMenu(person)
        }
    }


    private func lookAtMirror() {
        guard managesCommands, currentRoom == .bedroom, !showingMirror else { return }
        showingMirror = true
        contextBuffer.tag = 0
        Menus.shared.show(.palaceMirrorRoom)
        EventManager.uiStateChangedEvent.notify(UIStateEventData(
            rightPanel: .rect,
            directions: [],
            palacePlanVisible: false
        ))
    }


    private func lookAwayFromMirror() {
        guard showingMirror else { return }
        dismissMirror()
        updateRoomCommands()
        let view = GameState.shared.locationView()
        EventManager.uiStateChangedEvent.notify(UIStateEventData(
            rightPanel: .roomDirections,
            directions: view.directions
        ))
    }


    private func dismissMirror() {
        guard showingMirror else { return }
        showingMirror = false
        mirrorSprite = nil
        paulSprite = nil
        chaniSprite = nil
        contextBuffer.tag = 0
    }


    private func updateRoomCommands() {
        let present = charactersInRoom()
        roomCharacters = present
        var inRoom: UInt16 = 0
        var records: [MenuRecord] = []

        records.append(MenuRecord(textId: CommandId.seeDuneMap, handler: MenuHandler.seeDuneMap))

        if currentRoom == .bedroom {
            records.append(MenuRecord(textId: CommandId.lookAtMirror, handler: MenuHandler.lookAtMirror))
        } else {
            // List persons in room and add them in menu
            for person in present {
                inRoom |= UInt16(1) << person.personIndex
    
                records.append(MenuRecord(
                  textId: 0x6D + UInt16(person.personIndex),
                  handler: person.handler
                ))
            }
          
            GameState.shared.personsInRoom = inRoom
        }
        

        Menus.shared.setRecords(.command, records)
        Menus.shared.show(.command)
    }


    /// Scripted scenes pass an explicit cast. In play, each person stationed in
    /// this room stands on a SAL slot, unless they are travelling with Paul.
    private func syncStandingCharacters() {
        guard let palaceScenery else { return }
        let standing = standingCharacters(in: palaceScenery)
        guard palaceScenery.characters != standing else { return }
        palaceScenery.characters = standing
        contextBuffer.tag = 0
    }


    private func standingCharacters(in scenery: Scenery) -> [Int: RoomCharacter] {
        guard managesCommands else { return markers }

        let count = markerCount(in: scenery)
        guard count > 0 else { return [:] }

        let state = GameState.shared
        var present: UInt16 = 0
        for person in state.roomPersons where isStationedHere(person, state) {
            present |= UInt16(1) << person.personIndex
        }
        // persons_in_room XOR persons_travelling_with. Masking with the people
        // actually here drops a travelling bit that belongs to another room.
        let bits = present & ~state.personsTravellingWith

        var slots = [Int](repeating: -1, count: count)
        let base = Int(state.personMarkerBase & 0x0F)
        var id = 0
        var remaining = bits
        while remaining != 0 {
            if remaining & 1 != 0 {
                assignStandingSlot(&slots, id, base)
            }
            remaining >>= 1
            id += 1
        }

        var placed: [Int: RoomCharacter] = [:]
        for (slot, personId) in slots.enumerated() where personId >= 0 {
            if let character = RoomCharacter(rawValue: UInt16(personId) * 2) {
                placed[slot] = character
            }
        }
        return placed
    }


    private func markerCount(in scenery: Scenery) -> Int {
        guard scenery.rooms.indices.contains(roomIndex) else { return 0 }
        return scenery.rooms[roomIndex].commands.reduce(into: 0) { count, command in
            if command is RoomMarker {
                count += 1
            }
        }
    }


    /// Preferred slot is (person + base) mod the room's marker count. A taken slot spills to the first free one.
    private func assignStandingSlot(_ slots: inout [Int], _ personId: Int, _ base: Int) {
        let count = slots.count
        guard count > 0 else { return }
        let preferred = (personId + base) % count
        if slots[preferred] == -1 {
            slots[preferred] = personId
            return
        }
        if let free = slots.firstIndex(of: -1) {
            slots[free] = personId
        }
    }


    /// Residents match this room. Companions follow Paul and are listed after them.
    private func charactersInRoom() -> [DuneRoomPerson] {
        let state = GameState.shared
        var present: [DuneRoomPerson] = []
        for person in state.roomPersons where !person.flags.contains(.npcCompanion) && isStationedHere(person, state) {
            present.append(person)
        }
        for person in state.roomPersons where person.flags.contains(.npcCompanion) {
            present.append(person)
        }
        return present
    }


    private func isStationedHere(_ person: DuneRoomPerson, _ state: GameState) -> Bool {
        if person.personIndex == 4 && state.gamePhase >= 0x15 && state.gamePhase < 0x20 {
            return false
        }
        return person.locationAndRoom == state.locationAndRoom
            && person.locationAppearance == state.locationAppearance
    }


    private func showCharacterMenu(_ person: DuneRoomPerson) {
        GameState.shared.personTalkingTo = UInt16(1) << person.personIndex
        GameState.shared.currentSpeakerId = person.personIndex

        let comeGreyed = person.flags.contains(.npcNoComeWithMe)
            || (person.personIndex == 0x0C && person.flags.contains(.npcStoryBit))
        let travel = person.flags.contains(.npcCompanion)
            ? MenuRecord(textId: CommandId.stayHere, handler: 0x95e2)
            : MenuRecord(textId: CommandId.comeWithMe, handler: 0x95e2, greyed: comeGreyed)

        Menus.shared.setRecords(.npcActions, [
            MenuRecord(textId: CommandId.talkToMe, handler: 0x9472),
            travel,
            MenuRecord(textId: CommandId.stopTalking, handler: MenuHandler.exitMenu)
        ])
        Menus.shared.show(.npcActions)
    }


    private func renderMirror(_ buffer: PixelBuffer) {
        if mirrorSprite == nil {
            mirrorSprite = Sprite("MIRROR.HSQ")
            paulSprite = Sprite("PAUL.HSQ")
            paulSprite?.replaceAnimationsImageIndex(1, 9)
            if GameState.shared.personsTravellingWith & 0x80 != 0 {
                chaniSprite = Sprite("CHAN.HSQ")
            }
        }

        mirrorSprite?.setPalette()
        paulSprite?.setPalette()
        chaniSprite?.setPalette()

        if contextBuffer.tag != 0x0002 {
            contextBuffer.clearBuffer()
            mirrorSprite?.drawFrame(0, x: 0, y: 0, buffer: contextBuffer)
            mirrorSprite?.drawFrame(1, x: 0, y: 0, buffer: contextBuffer)
            contextBuffer.tag = 0x0002
        }

        contextBuffer.render(to: buffer)

        let withChani = chaniSprite != nil
        if withChani {
            chaniSprite?.drawAnimation(2, buffer: buffer, time: currentTime, offset: DunePoint(0, 15))
        }
        let paulOffset = withChani ? DuneCharacter.paulInMirror.offset : .zero
        paulSprite?.drawAnimation(0, buffer: buffer, time: currentTime, offset: paulOffset)
        mirrorSprite?.drawFrame(2, x: 0, y: 0, buffer: buffer)
    }
}
