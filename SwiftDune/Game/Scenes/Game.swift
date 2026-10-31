//
//  Game.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 24/08/2024.
//

import Foundation

final class Game: DuneNode {
    private var sceneNode: DuneNode?
    private var dialogueNode: DialogueOverlay?
    private var characterNode: Character?
    private var uiNode: UI?
    private var cursor: Cursor?
    private var dialoguePerson: UInt8?

    init() {
        super.init("Game")
    }


    override func onEnable() {
        EventManager.uiStateChangedEvent.addListener(self) { [weak self] state in
            guard let self = self else { return }
            self.onUIEvent(state)
        }

        EventManager.bookStateChangedEvent.addListener(self) { [weak self] state in
            guard let self = self else { return }
            self.onBookEvent(state)
        }

        EventManager.navigationEvent.addListener(self) { [weak self] event in
            self?.move(event.direction)
        }

        EventManager.menuChoiceEvent.addListener(self) { [weak self] event in
            self?.onMenuChoice(event.choice)
        }

        EventManager.showMapEvent.addListener(self) { [weak self] _ in
            self?.toggleMap()
        }

        EventManager.showFreskEvent.addListener(self) { [weak self] _ in
            self?.showFresk()
        }

        GameState.shared.prepareWorld()

        uiNode = UI()
        uiNode?.isActive = true

        dialogueNode = DialogueOverlay()

        if engine.input.mouseEnabled {
            cursor = Cursor()
        }

        showLocation()
    }


    override func onDisable() {
        sceneNode?.isActive = false
        sceneNode?.onDisable()
        sceneNode = nil
      
        dialogueNode?.isActive = false
        dialogueNode?.onDisable()
        dialogueNode = nil
      
        characterNode?.isActive = false
        characterNode?.onDisable()
        characterNode = nil
        
        uiNode?.onDisable()
      
        EventManager.uiStateChangedEvent.removeListener(self)
        EventManager.bookStateChangedEvent.removeListener(self)
        EventManager.navigationEvent.removeListener(self)
        EventManager.menuChoiceEvent.removeListener(self)
        EventManager.showMapEvent.removeListener(self)
        EventManager.showFreskEvent.removeListener(self)
    }


    func onUIEvent(_ e: UIStateEventData) {
        if e.leftPanel == .bookOpen {
            showBook()
        }
    }


    func onBookEvent(_ e: BookStateEventData) {
        if e.action == .close {
            showLocation()
        }
    }


    override func update(_ elapsedTime: TimeInterval) {
        refreshRoomMove()
        refreshTalk()
        sceneNode?.update(elapsedTime)
      
        if let dialogueNode, dialogueNode.isActive {
            dialogueNode.update(elapsedTime)
        }
      
        if let characterNode, characterNode.isActive {
            characterNode.update(elapsedTime)
        }
      
        uiNode?.update(elapsedTime)
    }


    override func render(_ buffer: PixelBuffer) {
        sceneNode?.render(buffer)
      
        if let dialogueNode, dialogueNode.isActive {
            dialogueNode.render(buffer)
        }
      
        if let characterNode, characterNode.isActive {
            characterNode.render(buffer)
        }
      
        uiNode?.render(buffer)
        cursor?.render(buffer)
    }


    override func onClick(_ event: DuneClickEvent) {
        sceneNode?.onClick(event)
        uiNode?.onClick(event)
    }

    override func onKey(_ event: DuneKeyEvent) {
        sceneNode?.onKey(event)

        if event.char.lowercased() == "m" {
            toggleMap()
            return
        }

        if let direction = event.specialKey.direction() {
            move(direction)
        }
    }


    func move(_ direction: Int) {
        if sceneNode?.handleNavigation(direction) == true {
            return
        }

        GameState.shared.move(direction)
        if GameState.shared.pendingRoomAction != 1 {
            showLocation()
        }
    }


    func showLocation() {
        uiNode?.closePalacePlan()

        let view = GameState.shared.locationView()
        switch view.kind {
        case .palace:
            showScene("Palace", [
                "room": view.salRoom,
                "commands": true
            ]) { Palace() }
        case .sietch:
            showScene("Sietch", ["room": view.salRoom]) { Sietch() }
        case .fort, .harkonnenPalace:
            showScene("Arrakeen", ["room": view.salRoom]) { Arrakeen() }
        case .village, .desert:
            showScene("DesertWalk", ["place": view.kind]) { DesertWalk() }
        }

        if sceneNode?.name != "Palace" {
            Menus.shared.setRecords(.command, [])
            Menus.shared.show(.command)
        }
      
        EventManager.uiStateChangedEvent.notify(UIStateEventData(
            rightPanel: .roomDirections,
            directions: view.directions
        ))
    }


    private func showScene(_ name: String, _ params: [String: Any], make: () -> DuneNode) {
        endTalk(restoreMenu: false)

        if sceneNode?.name == name {
            sceneNode?.params = params
            return
        }

        sceneNode?.isActive = false
        let node = make()
        node.params = params
        node.isActive = true
        sceneNode = node
    }


    func toggleMap() {
        if sceneNode?.name == "Map" {
            showLocation()
            return
        }

        showMap()
    }


    func showMap() {
        showScene("Map", [:]) { Map() }
    }


    func onMenuChoice(_ choice: MenuChoice) {
        switch choice.handler {
        case MenuHandler.seeDuneMap:
            showMap()
            break
        case MenuHandler.exitMaps:
            if sceneNode?.name == "Map" {
                toggleMap()
            }
            break
        case MenuHandler.exitGlobe:
            showLocation()
            break
        case MenuHandler.exitMenu:
            if choice.scenario == .npcActions {
                endTalk()
            }
            break
        case 0x9472:
            advanceTalk()
            break
        case 0x95e2:
            followOrStay()
            break
        default:
            break
        }
    }


    func showRoom() {
        showLocation()
    }


    func showFresk() {
        showScene("Fresk", [:]) { Fresk() }
    }


    func showBook() {
        showScene("Book", [:]) { Book() }
    }


    func showDialogue(_ text: String, speaker: Int) {
        if dialogueNode == nil {
            dialogueNode = DialogueOverlay()
        }
      
        dialogueNode?.params = ["text": text, "speaker": speaker]
      
        if dialogueNode?.isActive != true {
            dialogueNode?.isActive = true
        }
    }


    func hideDialogue() {
        dialogueNode?.isActive = false
    }


    func showCharacter(_ character: DuneCharacter, animations: [Int] = [0]) {
        if characterNode == nil {
            characterNode = Character()
        }
      
        if characterNode?.isActive == true {
            characterNode?.isActive = false
        }
      
        characterNode?.params = [
            "character": character,
            "animations": animations
        ]
        characterNode?.isActive = true
    }


    func hideCharacter() {
        characterNode?.isActive = false
        characterNode = nil
    }


    private func roomAcceptsTalk() -> Bool {
        switch sceneNode?.name {
        case "Palace", "Sietch", "Arrakeen":
            return true
        default:
            return false
        }
    }


    private func refreshRoomMove() {
        guard GameState.shared.pendingRoomAction == 1 else { return }

        let leaving = GameState.shared.runRoomAutoDialogue()
        GameState.shared.pendingRoomAction = 0
        if let leaving {
            presentAutoLine(leaving)
        }
        guard GameState.shared.dialogueInterruptGate == 0xFF else { return }

        GameState.shared.commitPendingRoomMove()
        showLocation()
        guard roomAcceptsTalk() else { return }
        if let entered = GameState.shared.runRoomAutoDialogue() {
            presentAutoLine(entered)
        }
    }


    private func presentAutoLine(_ line: RoomAutoLine) {
        GameState.shared.beginAutoTalk(with: line.person)
        dialoguePerson = line.person.personIndex
        zoom(on: line.person)
        Menus.shared.setRecords(.npcActions, GameState.shared.speechMenuRecords(for: line.person))
        Menus.shared.show(.npcActions)

        if let portrait = portrait(for: line.person.personIndex) {
            showCharacter(portrait)
        } else {
            hideCharacter()
        }

        if line.text.isEmpty {
            hideDialogue()
        } else {
            showDialogue(line.text, speaker: Int(line.person.personIndex))
        }
    }


    private func refreshTalk() {
        guard roomAcceptsTalk() else {
            if dialoguePerson != nil {
                endTalk(restoreMenu: false)
            }
            return
        }

        guard let person = GameState.shared.selectedRoomPerson() else {
            if dialoguePerson != nil {
                endTalk()
            }
            return
        }

        if dialoguePerson != person.personIndex {
            beginTalk(person)
        }
    }


    private func beginTalk(_ person: DuneRoomPerson) {
        GameState.shared.beginTalk(with: person)
        guard let text = GameState.shared.nextDialogueLine() else {
            GameState.shared.finishTalk()
            return
        }

        dialoguePerson = person.personIndex
        zoom(on: person)
        Menus.shared.setRecords(.npcActions, GameState.shared.speechMenuRecords(for: person))
        Menus.shared.show(.npcActions)

        if let portrait = portrait(for: person.personIndex) {
            showCharacter(portrait)
        } else {
            hideCharacter()
        }

        if text.isEmpty {
            hideDialogue()
        } else {
            showDialogue(text, speaker: Int(person.personIndex))
        }
    }


    private func advanceTalk() {
        guard dialoguePerson != nil else { return }
        guard let text = GameState.shared.nextDialogueLine() else {
            endTalk()
            return
        }
        if text.isEmpty {
            hideDialogue()
        } else if let dialoguePerson {
            showDialogue(text, speaker: Int(dialoguePerson))
        }
    }


    private func followOrStay() {
        guard let dialoguePerson else { return }
        guard let person = GameState.shared.toggleCompanion(personIndex: dialoguePerson) else { return }
        Menus.shared.setRecords(.npcActions, GameState.shared.speechMenuRecords(for: person))
        Menus.shared.show(.npcActions)
    }


    private func endTalk(restoreMenu: Bool = true) {
        guard dialoguePerson != nil || GameState.shared.personTalkingTo != 0 else { return }
        dialoguePerson = nil
        GameState.shared.finishTalk()
        hideDialogue()
        hideCharacter()

        guard restoreMenu else { return }
        let hadZoom = sceneNode?.params["zoom"] != nil
        clearZoom()
        if !hadZoom || sceneNode?.name != "Palace" {
            if Menus.shared.scenario == .npcActions {
                Menus.shared.show(.command)
            }
        }
    }


    private func zoom(on person: DuneRoomPerson) {
        guard sceneNode?.name == "Palace" else { return }
        let focal = Effects.talkingHeadFocalPoint(Int(person.personIndex))
        guard focal.x != 0 || focal.y != 0 else {
            clearZoom()
            return
        }

        let origin = Effects.zoomOrigin(focal: focal, scale: 6)
        let x = min(Int(origin.x), 0xF0)
        let y = min(Int(origin.y), 0x71)
        var next = sceneNode?.params ?? [:]
        next["zoom"] = DuneRect(Int16(x), Int16(y), 80, 38)
        sceneNode?.params = next
    }


    private func clearZoom() {
        guard sceneNode?.name == "Palace", sceneNode?.params["zoom"] != nil else { return }
        var next = sceneNode?.params ?? [:]
        next.removeValue(forKey: "zoom")
        sceneNode?.params = next
    }


    private func portrait(for personIndex: UInt8) -> DuneCharacter? {
        switch DialogueSpeaker(rawValue: personIndex) {
        case .leto:
            return .leto
        case .jessica:
            return .jessica
        case .thufir:
            return .thufir
        case .duncan:
            return .duncan
        case .gurney:
            return .gurney
        case .stilgar:
            return .stilgar
        case .kynes:
            return .liet
        case .chani:
            return .chani
        case .harah:
            return .harah
        case .baron:
            return .baron
        case .feyd:
            return .feyd
        case .emperor:
            return .emperor
        case .smugglers:
            return .smuggler
        case .fremen1:
            return .fremen1
        case .fremen2:
            return .fremen2
        case .harkonnenCaptain, .narrator, .none:
            return nil
        }
    }
}
