//
//  Prologue.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 24/03/2024.
//

import Foundation

/*
 // TODO: Prologue (sentences 267-274)
 
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
    private var queue = Queue<PrologueSteps>()
 
    init() {
        super.init("Prologue")
        
        attachNode(Stars())
        attachNode(Paul())
        attachNode(DesertBackground())
        attachNode(Sunrise())
        attachNode(Sietch())
        attachNode(Palace())
        attachNode(Baron())
        attachNode(PrologueSubtitle())
    }
    
    
    override func onEnable() {
        /*queue.enqueue(PrologueSteps(
            mainNode: DuneNodeParams("Stars", [ "mode": StarsMode.planets ]),
            subtitle: DuneNodeParams("PrologueSubtitle", [ "sentenceNumber": 267 ])
        ))*/
        /*queue.enqueue(PrologueSteps(
            mainNode: DuneNodeParams("Stars", [ "mode": StarsMode.globe ]),
            subtitle: DuneNodeParams("PrologueSubtitle", [ "sentenceNumber": 268 ])
        ))*/
        /*queue.enqueue(PrologueSteps(
            mainNode: DuneNodeParams("DesertBackground", [:]),
            subtitle: DuneNodeParams("PrologueSubtitle", [ "sentenceNumber": 269 ])
        ))*/
        /*queue.enqueue(PrologueSteps(
            mainNode: DuneNodeParams("Paul", [ "background": PaulBackground.red ]),
            subtitle: DuneNodeParams("PrologueSubtitle", [ "sentenceNumber": 270 ])
        ))*/
        queue.enqueue(PrologueSteps(
            mainNode: DuneNodeParams("Baron", [ "animation": 5 ]),
            subtitle: DuneNodeParams("PrologueSubtitle", [ "sentenceNumber": 271 ])
        ))
        /*queue.enqueue(PrologueSteps(
            mainNode: DuneNodeParams("Stars", [ "mode": StarsMode.globe ]),
            subtitle: DuneNodeParams("PrologueSubtitle", [ "sentenceNumber": 272 ])
        ))*/
        /*queue.enqueue(PrologueSteps(
            mainNode: DuneNodeParams("Paul", [ "background": PaulBackground.red ]),
            subtitle: DuneNodeParams("PrologueSubtitle", [ "sentenceNumber": 273 ])
        ))*/
        /*queue.enqueue(PrologueSteps(
            mainNode: DuneNodeParams("Flight", [ "mode": .night ]),
            subtitle: DuneNodeParams("PrologueSubtitle", [ "sentenceNumber": 274 ])
        ))*/

        engine.addEventObserver(self)

        guard let item = queue.dequeueFirst() else {
            return
        }

        processNextStep(item)
    }
    
    
    override func onDisable() {
        queue.empty()
        engine.removeEventObserver(self)
    }
    
    
    func onEvent(_ source: String, _ e: DuneEvent) {
        if !self.isActive || !self.isChildNode(source) {
            return
        }
        
        setNodeActive(source, false)
        
        guard let nextItem = queue.dequeueFirst() else {
            engine.sendEvent(self, .nodeEnded)
            // engine.setNodeActive("Game", true)
            return
        }
        
        processNextStep(nextItem)
    }
    
    
    private func processNextStep(_ step: PrologueSteps) {
        if let mainNode = findNode(step.mainNode.name) {
            mainNode.params = step.mainNode.params
            setNodeActive(step.mainNode.name, true)
        }
        
        if let subtitleNode = findNode(step.subtitle.name) {
            subtitleNode.params = step.subtitle.params
            setNodeActive(step.subtitle.name, true)
        }
    }
}
