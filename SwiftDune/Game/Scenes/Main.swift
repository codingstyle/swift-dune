//
//  Main.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 08/03/2024.
//

import Foundation

final class Main: DuneNode {
    private var queue = Queue<DuneNodeParams>()
    // The comparison build should enter gameplay directly. The original
    // copy-protection node still waits for typed input even when bypassed.
    private let skipCopyProtection = true

    init() {
        super.init("Main")
        
        attachNode(Logo())
        attachNode(Intro())
        attachNode(Credits())
        attachNode(Prologue())
        attachNode(CopyProtection())
        attachNode(Game())
    }
    
    
    override func onEnable() {
        EventManager.nodeEndedEvent.addListener(self) { [weak self] nodeData in
            guard let self = self else { return }
            self.onNodeEvent(nodeData)
        }
        
        // The CD release has none of the floppy intro's files (its intro is
        // HNM clips, not ported yet): it starts in the game.
        if !DevHarness.shared.startInGame && !DuneArchive.isCD {
            queue.enqueue(DuneNodeParams("Logo"))
            queue.enqueue(DuneNodeParams("Intro"))
            queue.enqueue(DuneNodeParams("Credits"))
            queue.enqueue(DuneNodeParams("Prologue"))
        }
        if !skipCopyProtection && !DevHarness.shared.startInGame {
            queue.enqueue(DuneNodeParams("CopyProtection", [ "bypassProtection": true ]))
        }
        queue.enqueue(DuneNodeParams("Game"))

        guard let itemConfig = queue.dequeueFirst() else {
            return
        }
  
        if let node = findNode(itemConfig.name) {
            node.params = itemConfig.params
            setNodeActive(itemConfig.name, true)
        }
    }
    
    
    override func onDisable() {
        queue.empty()
        EventManager.nodeEndedEvent.removeListener(self)
    }
    
    
    override func render(_ screenBuffer: PixelBuffer) {
        screenBuffer.clearBuffer()

        nodes.filter { $0.isActive }.forEach { node in
            node.render(screenBuffer)
        }
    }
    
    
    func onNodeEvent(_ e: NodeEventData) {
        if !self.isActive || !self.isChildNode(e.nodeName) {
            return
        }
        
        moveToNextNode()
    }
    
    
    private func moveToNextNode() {
        guard let activeNode = activeNodes.first else {
            return
        }
        
        setNodeActive(activeNode.name, false)

        guard let nextItemConfig = queue.dequeueFirst() else {
            setNodeActive("Main", false)
            EventManager.nodeEndedEvent.notify(NodeEventData("Main"))
            return
        }
        
      if let nextItem = findNode(nextItemConfig.name) {
            nextItem.params = nextItemConfig.params
            setNodeActive(nextItemConfig.name, true)
        }
    }
    
    
    override func onKey(_ key: DuneKeyEvent) {
        guard let activeNode = activeNodes.first else {
            return
        }
        
        // Prologue iterates screen by screen
        if activeNode.name == "Prologue" || activeNode.name == "CopyProtection" || activeNode.name == "Game" {
            super.onKey(key)
        } else {
            moveToNextNode()
        }
    }
}
