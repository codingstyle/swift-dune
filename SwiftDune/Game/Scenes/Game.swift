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
        
        showBook()
        showUI()
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
