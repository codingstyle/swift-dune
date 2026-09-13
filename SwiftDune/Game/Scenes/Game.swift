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
      
      showRoom()
      showUI()
    }
  
    func showRoom() {
        if currentTime == 0.0 {
            let music = Music("ARRAKIS.HSQ", player: engine.audioPlayer)
            engine.audioPlayer.play(music)
        }

        let palaceNode = Palace()
        palaceNode.params = [
          "room": PalaceRoom.porch,
          "markers": [
            8: RoomCharacter.leto
          ]
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
