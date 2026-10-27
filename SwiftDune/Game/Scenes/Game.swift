//
//  Game.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 24/08/2024.
//

import Foundation

final class Game: DuneNode {
    private var sceneNode: DuneNode?
    private var uiNode: UI?
    private var cursor: Cursor?

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

        if engine.input.mouseEnabled {
            cursor = Cursor()
        }

        showLocation()
    }


    override func onDisable() {
        sceneNode?.isActive = false
        sceneNode = nil
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
        sceneNode?.update(elapsedTime)
        uiNode?.update(elapsedTime)
    }


    override func render(_ buffer: PixelBuffer) {
        sceneNode?.render(buffer)
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
        showLocation()
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
}
