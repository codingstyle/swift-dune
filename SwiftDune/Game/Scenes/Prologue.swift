//
//  Prologue.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 24/03/2024.
//

import Foundation

/*
 267 - Stars
 268 - Stars with Globe - tilted top and rotated right
 269 - Desert (same bg as Paul)
 270 - Paul with red background - Anim 3 ?
 271 - Baron - anim 5
 272 - Stars with Globe - tilted top and rotated right
 273 - Paul with red background - Anim 3 ?
 274 - Night view with desert and Arrakeen
 None - Carthag scene entrace with sunrise and fade on entrance scene
 */

struct PrologueSteps {
    var mainNode: DuneNodeParams
    var subtitle: DuneNodeParams
}


final class Prologue: DuneNode, DuneEventObserver {
    private let engine = DuneEngine.shared
    private var buffer = PixelBuffer(width: 320, height: 200)
    private var queue = Queue<PrologueSteps>()
    private var currentTime: TimeInterval = 0.0
    private var duration: TimeInterval = 999.0
 
    init() {
        super.init("Prologue")
        
        attachNode(Stars())
        attachNode(Paul())
        attachNode(DesertBackground())
        attachNode(Sunrise())
        attachNode(Sietch())
        attachNode(Palace())
        attachNode(Baron())
        attachNode(DesertWalk())
        attachNode(PrologueSubtitle())
    }
    
    
    override func onEnable() {
        queue.enqueue(PrologueSteps(
            mainNode: DuneNodeParams("Stars", [ "mode": StarsMode.planets ]),
            subtitle: DuneNodeParams("PrologueSubtitle", [ "sentenceNumber": 267 ])
        ))
        queue.enqueue(PrologueSteps(
            mainNode: DuneNodeParams("Stars", [ "mode": StarsMode.globe ]),
            subtitle: DuneNodeParams("PrologueSubtitle", [ "sentenceNumber": 268 ])
        ))
        queue.enqueue(PrologueSteps(
            mainNode: DuneNodeParams("DesertBackground", [:]),
            subtitle: DuneNodeParams("PrologueSubtitle", [ "sentenceNumber": 269 ])
        ))
        queue.enqueue(PrologueSteps(
            mainNode: DuneNodeParams("Paul", [ "background": PaulBackground.red, "duration": 999.0 ]),
            subtitle: DuneNodeParams("PrologueSubtitle", [ "sentenceNumber": 270 ])
        ))
        queue.enqueue(PrologueSteps(
            mainNode: DuneNodeParams("Baron", [ "animation": 5, "duration": 999.0 ]),
            subtitle: DuneNodeParams("PrologueSubtitle", [ "sentenceNumber": 271 ])
        ))
        queue.enqueue(PrologueSteps(
            mainNode: DuneNodeParams("Stars", [ "mode": StarsMode.globe ]),
            subtitle: DuneNodeParams("PrologueSubtitle", [ "sentenceNumber": 272 ])
        ))
        queue.enqueue(PrologueSteps(
            mainNode: DuneNodeParams("Paul", [ "background": PaulBackground.red, "duration": 999.0 ]),
            subtitle: DuneNodeParams("PrologueSubtitle", [ "sentenceNumber": 273 ])
        ))
        queue.enqueue(PrologueSteps(
            mainNode: DuneNodeParams("DesertWalk", [ "dayMode": DuneLightMode.night ]),
            subtitle: DuneNodeParams("PrologueSubtitle", [ "sentenceNumber": 274 ])
        ))
        queue.enqueue(PrologueSteps(
            mainNode: DuneNodeParams("Palace", [ "room": PalaceRoom.stairs, "dayMode": DuneLightMode.sunrise ]),
            subtitle: DuneNodeParams("PrologueSubtitle", [:])
        ))

        engine.addEventObserver(self)

        processNextStep()
    }
    
    
    override func onDisable() {
        queue.empty()
        engine.removeEventObserver(self)
    }
    
    
    func onEvent(_ source: String, _ e: DuneEvent) {
        if !self.isActive || !self.isChildNode(source) {
            return
        }
        
        processNextStep()
    }
    
    
    override func onKey(_ key: DuneKeyEvent) {
        duration = currentTime + 1.0
    }
    
    
    private func processNextStep() {
        nodes.filter { $0.isActive }.forEach { node in
            setNodeActive(node.name, false)
        }

        guard let nextItem = queue.dequeueFirst() else {
            engine.sendEvent(self, .nodeEnded)
            return
        }
        
        currentTime = 0.0
        duration = 999.0
        
        if let mainNode = findNode(nextItem.mainNode.name) {
            mainNode.params = nextItem.mainNode.params
            setNodeActive(nextItem.mainNode.name, true)
        }
        
        if let subtitleNode = findNode(nextItem.subtitle.name) {
            subtitleNode.params = nextItem.subtitle.params
            setNodeActive(nextItem.subtitle.name, true)
        }
        
        // Prerender so that palette is stashed
        engine.palette.unstash()

        nodes.filter { $0.isActive }.forEach { node in
            node.render(buffer)
        }
        
        engine.palette.stash()
    }
    
    
    override func update(_ elapsedTime: TimeInterval) {
        nodes.filter { $0.isActive }.forEach { node in
            node.update(elapsedTime)
        }
        
        currentTime += elapsedTime
        
        if currentTime > duration {
            processNextStep()
        }
    }
    
    
    
    override func render(_ screenBuffer: PixelBuffer) {
        // Render nodes from intro
        buffer.clearBuffer()

        nodes.filter { $0.isActive }.forEach { node in
            node.render(buffer)
        }
        
        var fx: SpriteEffect {
            if currentTime < 1.0 {
                return .fadeIn(start: 0.0, duration: 1.0, current: currentTime)
            } else if currentTime > duration - 1.0 {
                return .fadeOut(end: duration, duration: 1.0, current: currentTime)
            }

            return .none
        }
        
        buffer.render(to: screenBuffer, effect: fx)
    }
}
