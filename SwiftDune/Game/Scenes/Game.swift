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
        
        showRoom()
        showUI()
    }
  
  
    func showRoom() {
        let palaceNode = Palace()
        palaceNode.params = [
          "room": PalaceRoom.porch
        ]
        attachNode(palaceNode)
        setNodeActive("Palace", true)
    }

    
    func showUI() {
        attachNode(UI())
        setNodeActive("UI", true)
    }
    
    
    func showFresk() {
        attachNode(Fresk())
        setNodeActive("Fresk", true)
    }
    
    
    func showBook() {
        attachNode(Book())
        setNodeActive("Book", true)
    }
}
