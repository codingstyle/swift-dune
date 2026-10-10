//
//  Game.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 24/08/2024.
//

import Foundation

final class Game: DuneNode {
    private var transitionIn: TransitionEffect?
    private var transitionOut: TransitionEffect?
  
    private var uiNode: UI?
    private var cursor: Cursor?
  
    init() {
        super.init("Game")
    }

  
    override func onEnable() {
      engine.palette.clear()
      
      EventManager.uiStateChangedEvent.addListener(self) { [weak self] state in
        guard let self = self else { return }
        self.onUIEvent(state)
      }
      
      
      EventManager.bookStateChangedEvent.addListener(self) { [weak self] state in
        guard let self = self else { return }
        self.onBookEvent(state)
      }
      
      attachNode(Palace())
      attachNode(Fresk())
      attachNode(Book())
      
      showRoom()

      uiNode = UI()
      uiNode?.onEnable()
      uiNode?.isActive = true
      
      cursor = Cursor()
    }
  
  
    override func onDisable() {
        uiNode?.onDisable()
        EventManager.uiStateChangedEvent.removeListener(self)
    }
  
  
    func onUIEvent(_ e: UIStateEventData) {
        if e.leftPanel == .bookOpen {
            showBook()
        }
    }
  
  
    func onBookEvent(_ e: BookStateEventData) {
        if e.action == .close {
            showRoom()
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
  
  
    override func onClick(_ event: DuneMouseClickEvent) {
        super.onClick(event)
        uiNode?.onClick(event)
    }
  
  
    func showRoom() {
        setNodeActive("Fresk", false)
        setNodeActive("Book", false)
      
        setNodeActive("Palace", true)
        setNodeParams("Palace", [
          "room": PalaceRoom.porch,
          "markers": [
            8: RoomCharacter.leto
          ]
        ])
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
