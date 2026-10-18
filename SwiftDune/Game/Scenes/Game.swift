//
//  Game.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 24/08/2024.
//

import Foundation

final class Game: DuneNode {
    private var uiNode: UI?
    private var cursor: Cursor?
    private var shownKind: DunePlaceKind?
    private var mapVisible = false
  
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
      
      GameState.shared.prepareWorld()

      attachNode(Palace())
      attachNode(Sietch())
      attachNode(Arrakeen())
      attachNode(DesertWalk())
      attachNode(Map())
      attachNode(Fresk())
      attachNode(Book())

      EventManager.navigationEvent.addListener(self) { [weak self] event in
        self?.move(event.direction)
      }

      EventManager.menuChoiceEvent.addListener(self) { [weak self] event in
        self?.onMenuChoice(event.choice)
      }
      
      showLocation()

      uiNode = UI()
      uiNode?.onEnable()
      uiNode?.isActive = true
      
      if engine.input.mouseEnabled {
          cursor = Cursor()
      }
    }
  
  
    override func onDisable() {
        uiNode?.onDisable()
        EventManager.uiStateChangedEvent.removeListener(self)
        EventManager.navigationEvent.removeListener(self)
        EventManager.menuChoiceEvent.removeListener(self)
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
        super.update(elapsedTime)
        uiNode?.update(elapsedTime)
    }
  
  
    override func render(_ buffer: PixelBuffer) {
        super.render(buffer)
      
        uiNode?.render(buffer)
        cursor?.render(buffer)
    }
  
  
    override func onClick(_ event: DuneClickEvent) {
        super.onClick(event)
      
        uiNode?.onClick(event)
      
        if viewingMirror && event.point.y < 152 {
            lookAwayFromMirror()
        }
    }

    override func onKey(_ event: DuneKeyEvent) {
        super.onKey(event)
      
        if event.char.lowercased() == "m" {
            toggleMap()
            return
        }
      
        let direction: Int?
        
        switch event.specialKey {
          case .keyUp: direction = 1
          case .keyRight: direction = 2
          case .keyDown: direction = 3
          case .keyLeft: direction = 4
          default: direction = nil
        }
      
        if let direction {
            move(direction)
        }
    }


    func move(_ direction: Int) {
        if viewingMirror || findNode("Book")?.isActive == true || findNode("Fresk")?.isActive == true {
            return
        }
      
        if mapVisible {
            (findNode("Map") as? Map)?.pan(direction)
            return
        }
      
        GameState.shared.move(direction)
        showLocation()
    }


    func showLocation() {
        mapVisible = false
        setNodeActive("Fresk", false)
        setNodeActive("Book", false)
        setNodeActive("Map", false)
        uiNode?.closePalacePlan()

        let view = GameState.shared.locationView()
        if view.kind != shownKind {
            setNodeActive("Palace", false)
            setNodeActive("Sietch", false)
            setNodeActive("Arrakeen", false)
            setNodeActive("DesertWalk", false)
            shownKind = view.kind
        }

        switch view.kind {
        case .palace:
            var roomParams: [String: Any] = ["room": view.salRoom]
            roomParams["markers"] = view.salRoom == PalaceRoom.porch.rawValue
                ? [8: RoomCharacter.leto]
                : Dictionary<Int, RoomCharacter>()
            showScene("Palace", roomParams)
        case .sietch:
            showScene("Sietch", ["room": view.salRoom])
        case .fort, .harkonnenPalace:
            showScene("Arrakeen", ["room": view.salRoom])
        case .village, .desert:
            showScene("DesertWalk", ["place": view.kind])
        }

        if view.kind == .palace && view.salRoom == PalaceRoom.bedroom.rawValue {
            Menus.shared.setRecords(.command, [
                MenuRecord(textId: CommandId.lookAtMirror, handler: MenuHandler.lookAtMirror)
            ])
        } else {
            Menus.shared.setRecords(.command, [])
        }
        Menus.shared.show(.command)
        EventManager.uiStateChangedEvent.notify(UIStateEventData(
            rightPanel: .roomDirections,
            directions: view.directions
        ))
    }


    private var viewingMirror: Bool {
        (findNode("Palace") as? Palace)?.isShowingMirror == true
    }


    private func lookAtMirror() {
        let view = GameState.shared.locationView()
        guard view.kind == .palace, view.salRoom == PalaceRoom.bedroom.rawValue else {
            return
        }
        uiNode?.closePalacePlan()
        showScene("Palace", [
            "room": PalaceRoom.bedroom.rawValue,
            "markers": Dictionary<Int, RoomCharacter>(),
            "mirror": true
        ])
        EventManager.uiStateChangedEvent.notify(UIStateEventData(rightPanel: .rect, directions: []))
    }


    private func lookAwayFromMirror() {
        guard viewingMirror else { return }
        showLocation()
    }


    private func showScene(_ name: String, _ params: [String: Any]) {
        setNodeParams(name, params)
        if findNode(name)?.isActive != true {
            setNodeActive(name, true)
        }
    }


    func toggleMap() {
        mapVisible.toggle()
        if mapVisible {
            setNodeActive("Palace", false)
            setNodeActive("Sietch", false)
            setNodeActive("Arrakeen", false)
            setNodeActive("DesertWalk", false)
            setNodeActive("Fresk", false)
            setNodeActive("Book", false)
            shownKind = nil
            setNodeActive("Map", true)
            Menus.shared.show(.mapTroops)
            EventManager.uiStateChangedEvent.notify(UIStateEventData(rightPanel: .mapDirections))
            return
        }
        showLocation()
    }
  
  
    func onMenuChoice(_ choice: MenuChoice) {
        switch choice.handler {
        case MenuHandler.exitMaps:
            if mapVisible {
                toggleMap()
            }
        case MenuHandler.exitGlobe:
            showLocation()
        case MenuHandler.lookAtMirror:
            lookAtMirror()
        case MenuHandler.lookAwayFromTheMirror:
            lookAwayFromMirror()
        default:
            break
        }
    }


    func showRoom() {
        showLocation()
    }

    
    func showFresk() {
        setNodeActive("Book", false)
        setNodeActive("Palace", false)
        setNodeActive("Fresk", true)
    }
    
    
    func showBook() {
      setNodeActive("Fresk", false)
      setNodeActive("Palace", false)
      setNodeActive("Book", true)
    }
}
