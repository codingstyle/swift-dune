//
//  Game.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 24/08/2024.
//

import Foundation

final class Game: DuneNode {
    
    init() {
        super.init("Game")
    }

  
    override func onEnable() {
      engine.palette.clear()
      
      EventManager.uiStateChangedEvent.addListener(self) { [weak self] state in
        guard let self = self else { return }
        self.onUIEvent(state)
      }
      
      showRoom()
      showUI()
    }
  
  
    override func onDisable() {
        EventManager.uiStateChangedEvent.removeListener(self)
    }
  
  
    func onUIEvent(_ e: UIStateEventData) {
        if e.leftPanel == .bookOpen {
            showBook()
        }
    }
  
  
    func showRoom() {
        let palaceNode = Palace()
        palaceNode.params = [
          "room": PalaceRoom.porch,
          "markers": [
            8: RoomCharacter.leto
          ]
        ]
        attachNode(palaceNode)
        setNodeActive("Fresk", false)
        setNodeActive("Book", false)
        setNodeActive("Palace", true)
    }

    
    func showUI() {
        attachNode(UI())
        setNodeActive("UI", true)
    }
    
    
    func showFresk() {
        attachNode(Fresk())
        setNodeActive("Book", false)
        setNodeActive("Palace", false)
        setNodeActive("Fresk", true)
    }
    
    
    func showBook() {
      attachNode(Book())
      setNodeActive("Fresk", false)
      setNodeActive("Palace", false)
      setNodeActive("Book", true)
    }
}
