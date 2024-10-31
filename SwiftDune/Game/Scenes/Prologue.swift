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
    var background: DuneNodeParams
    var foreground: DuneNodeParams?
    var subtitle: DuneNodeParams
}


final class Prologue: DuneNode, DuneEventObserver {
    private var buffer = PixelBuffer(width: 320, height: 200)
    private var queue = Queue<PrologueSteps>()
 
    init() {
        super.init("Prologue")
        
        attachNode(Stars())
        attachNode(Background())
        attachNode(Character())
        attachNode(Sunrise())
        attachNode(Sietch())
        attachNode(Palace())
        attachNode(DesertWalk())
        attachNode(PrologueSubtitle())
    }
    
    
    override func onEnable() {
        queue.enqueue(PrologueSteps(
            background: DuneNodeParams("Stars", [ "mode": StarsMode.planets ]),
            subtitle: DuneNodeParams("PrologueSubtitle", [ "sentenceNumber": 267 ])
        ))
        queue.enqueue(PrologueSteps(
            background: DuneNodeParams("Stars", [ "mode": StarsMode.globe ]),
            subtitle: DuneNodeParams("PrologueSubtitle", [ "sentenceNumber": 268 ])
        ))
        queue.enqueue(PrologueSteps(
            background: DuneNodeParams("Background", [ "backgroundType": BackgroundType.desert ]),
            subtitle: DuneNodeParams("PrologueSubtitle", [ "sentenceNumber": 269 ])
        ))
        queue.enqueue(PrologueSteps(
            background: DuneNodeParams("Background", [ "backgroundType": BackgroundType.red ]),
            foreground: DuneNodeParams("Character", [ "character": DuneCharacter.paul ]),
            subtitle: DuneNodeParams("PrologueSubtitle", [ "sentenceNumber": 270 ])
        ))
        queue.enqueue(PrologueSteps(
            background: DuneNodeParams("Background", [ "backgroundType": BackgroundType.baron ]),
            foreground: DuneNodeParams("Character", [ "character": DuneCharacter.baron, "animations": [ 5 ] ]),
            subtitle: DuneNodeParams("PrologueSubtitle", [ "sentenceNumber": 271 ])
        ))
        queue.enqueue(PrologueSteps(
            background: DuneNodeParams("Stars", [ "mode": StarsMode.globe ]),
            subtitle: DuneNodeParams("PrologueSubtitle", [ "sentenceNumber": 272 ])
        ))
        queue.enqueue(PrologueSteps(
            background: DuneNodeParams("Background", [ "backgroundType": BackgroundType.red ]),
            foreground: DuneNodeParams("Character", [ "character": DuneCharacter.paul ]),
            subtitle: DuneNodeParams("PrologueSubtitle", [ "sentenceNumber": 273 ])
        ))
        queue.enqueue(PrologueSteps(
            background: DuneNodeParams("DesertWalk", [ "dayMode": DuneLightMode.night ]),
            subtitle: DuneNodeParams("PrologueSubtitle", [ "sentenceNumber": 274 ])
        ))
        queue.enqueue(PrologueSteps(
            background: DuneNodeParams("Palace", [ "room": PalaceRoom.stairs, "dayMode": DuneLightMode.sunrise ]),
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

        if let backgroundNode = findNode(nextItem.background.name) {
            backgroundNode.params = nextItem.background.params
            setNodeActive(nextItem.background.name, true, .background)
        }

        if let foreground = nextItem.foreground {
            if let foregroundNode = findNode(foreground.name) {
                foregroundNode.params = foreground.params
                setNodeActive(foreground.name, true, .foreground)
            }
        }
        
        if let subtitleNode = findNode(nextItem.subtitle.name) {
            subtitleNode.params = nextItem.subtitle.params
            setNodeActive(nextItem.subtitle.name, true, .foreground)
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
