//
//  Main.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 08/03/2024.
//

import Foundation

final class Main: DuneNode, DuneEventObserver {
    private let engine = DuneEngine.shared
    private var queue = Queue<String>()

    init() {
        super.init("Main")
        
        attachNode(Logo())
        attachNode(Intro())
        attachNode(Credits())
        attachNode(Prologue())

        // TODO: Copy protection
        // TODO: Main game phase
    }
    
    
    override func onEnable() {
        engine.addEventObserver(self)
        
        queue.enqueue("Logo")
        queue.enqueue("Intro")
        queue.enqueue("Credits")
        queue.enqueue("Prologue")
        
        guard let itemName = queue.dequeueFirst() else {
            return
        }

        if let _ = findNode(itemName) {
            setNodeActive(itemName, true)
        }
    }
    
    
    override func onDisable() {
        queue.empty()
        engine.removeEventObserver(self)
    }
    
    
    override func render(_ screenBuffer: PixelBuffer) {
        screenBuffer.clearBuffer()

        nodes.filter { $0.isActive }.forEach { node in
            node.render(screenBuffer)
        }
    }
    
    
    func onEvent(_ source: String, _ e: DuneEvent) {
        if !self.isActive || !self.isChildNode(source) {
            return
        }
        
        moveToNextNode()
    }
    
    
    private func moveToNextNode() {
        guard let activeNode = activeNodes.first else {
            return
        }
        
        setNodeActive(activeNode.name, false)

        guard let nextItem = queue.dequeueFirst() else {
            setNodeActive("Main", false)
            engine.sendEvent(self, .nodeEnded)
            return
        }
        
        if let _ = findNode(nextItem) {
            setNodeActive(nextItem, true)
        }
    }
    
    
    override func onKey(_ key: DuneKeyEvent) {
        guard let activeNode = activeNodes.first else {
            return
        }
        
        // Prologue iterates screen by screen
        if activeNode.name == "Prologue" {
            super.onKey(key)
        } else {
            moveToNextNode()
        }
    }
}
