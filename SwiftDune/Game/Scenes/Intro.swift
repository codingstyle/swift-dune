//
//  Intro.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 18/12/2023.
//

import Foundation


struct IntroSteps {
    var foregroundNode: [DuneNodeParams]
    var backgroundNodes: [DuneNodeParams]
}


final class Intro: DuneNode, DuneEventObserver {
    private var buffer = PixelBuffer(width: 320, height: 152)
    private var engine = DuneEngine.shared
    
    private var queue = Queue<DuneNodeParams>()
    
    init() {
        super.init("Intro")
        
        attachNode(LogoSwap())
        attachNode(Presents())
        attachNode(Stars())
        attachNode(DuneTitle())
        attachNode(Worm())
        attachNode(Paul())
        attachNode(Sunrise())
        attachNode(Sietch())
        attachNode(DesertWalk())
        attachNode(Palace())
        attachNode(Baron())
        attachNode(Feyd())
        attachNode(Kiss())
        attachNode(Attack())
        attachNode(Ornithopter())
        attachNode(Flight())
    }

    override func onEnable() {
        queue.enqueue(DuneNodeParams("LogoSwap"))
        queue.enqueue(DuneNodeParams("Presents"))
        queue.enqueue(DuneNodeParams("Stars", [ "mode": StarsMode.planets, "transitionIn": TransitionEffect.fadeIn(duration: 7.34), "duration": 9.34 ]))
        queue.enqueue(DuneNodeParams("Stars", [ "mode": StarsMode.planetsPan, "duration": 2.55 ]))
        queue.enqueue(DuneNodeParams("Stars", [ "mode": StarsMode.arrakisZoom, "duration": 0.5 ]))
        queue.enqueue(DuneNodeParams("DuneTitle"))
        queue.enqueue(DuneNodeParams("Worm"))
        queue.enqueue(DuneNodeParams("Paul", [ "background": PaulBackground.red, "transitionIn": TransitionEffect.fadeIn(duration: 2.0), "transitionOut": TransitionEffect.fadeOut(duration: 2.0) ]))
        queue.enqueue(DuneNodeParams("Sunrise", [ "mode": DuneLightMode.sunrise, "transitionIn": TransitionEffect.fadeIn(duration: 2.0), "duration" : 8.0 ]))
        queue.enqueue(DuneNodeParams("Sunrise", [ "mode": DuneLightMode.day, "zoomOut": true, "character": DuneCharacter.chani, "duration": 2.5 ]))
        queue.enqueue(DuneNodeParams("Sunrise", [ "mode": DuneLightMode.day, "character": DuneCharacter.chani ]))
        queue.enqueue(DuneNodeParams("Sunrise", [ "mode": DuneLightMode.day, "character": DuneCharacter.liet ]))
        queue.enqueue(DuneNodeParams("Sunrise", [ "mode": DuneLightMode.day, "character": DuneCharacter.chani, "duration": 2.0 ]))
        queue.enqueue(DuneNodeParams("Paul", [ "background": PaulBackground.desert, "transitionOut": TransitionEffect.fadeOut(duration: 2.0), "duration": 4.0 ]))
        queue.enqueue(DuneNodeParams("Sietch", [ "room": SietchRoom.room8, "duration": 4.0, "transitionIn": TransitionEffect.fadeIn(duration: 2.0), "markers": [
            6: RoomCharacter.harah,
            9: RoomCharacter.stilgar
        ] ] ))
        queue.enqueue(DuneNodeParams("Sietch", [ "room": SietchRoom.water, "duration": 4.0, "waterDrop": true ]))
        queue.enqueue(DuneNodeParams("Sietch", [ "room": SietchRoom.room8, "duration": 4.0, "markers": [
            6: RoomCharacter.harah,
            9: RoomCharacter.stilgar
        ]]))
        queue.enqueue(DuneNodeParams("Sietch", [ "room": SietchRoom.water, "duration": 4.0, "character": DuneCharacter.stilgar, "transitionOut": TransitionEffect.dissolveOut(duration: 0.3) ]))
        queue.enqueue(DuneNodeParams("DesertWalk", [ "dayMode": DuneLightMode.day, "duration": 2.0, "transitionIn": TransitionEffect.dissolveIn(duration: 0.3) ]))
        queue.enqueue(DuneNodeParams("Palace", [ "room": PalaceRoom.stairs, "duration": 2.0 ]))
        queue.enqueue(DuneNodeParams("Palace", [ "room": PalaceRoom.balcony, "duration": 2.0, "markers": [
            4: RoomCharacter.gurney,
            5: RoomCharacter.duncan,
            6: RoomCharacter.thufir,
            7: RoomCharacter.jessica,
            8: RoomCharacter.leto
        ]]))
        queue.enqueue(DuneNodeParams("Palace", [ "room": PalaceRoom.balcony, "duration": 4.0, "character": DuneCharacter.leto, "zoom": DuneRect(75, 45, 84, 40) ]))
        queue.enqueue(DuneNodeParams("Palace", [ "room": PalaceRoom.balcony, "duration": 4.0, "character": DuneCharacter.jessica, "zoom": DuneRect(170, 63, 84, 40), "transitionOut": TransitionEffect.dissolveOut(duration: 0.3) ]))
        queue.enqueue(DuneNodeParams("Paul", [ "background": PaulBackground.red, "duration": 4.0, "transitionIn": TransitionEffect.dissolveIn(duration: 0.3), "transitionOut": TransitionEffect.dissolveOut(duration: 0.3) ]))
        queue.enqueue(DuneNodeParams("Sunrise", [ "mode": DuneLightMode.sunset, "fort": true, "duration": 5.0, "transitionIn": TransitionEffect.dissolveIn(duration: 0.3), "transitionOut": TransitionEffect.dissolveOut(duration: 0.3) ]))
        queue.enqueue(DuneNodeParams("Baron", [ "duration": 2.0, "transitionIn": TransitionEffect.dissolveIn(duration: 0.3) ]))
        queue.enqueue(DuneNodeParams("Feyd", [ "duration": 4.0 ]))
        queue.enqueue(DuneNodeParams("Baron", [ "duration": 3.0, "sardaukar": true, "transitionOut": TransitionEffect.dissolveOut(duration: 0.3) ]))
        queue.enqueue(DuneNodeParams("Attack", [ "transitionIn": TransitionEffect.dissolveIn(duration: 0.3), "transitionOut": TransitionEffect.dissolveOut(duration: 0.3) ]))
        queue.enqueue(DuneNodeParams("Paul", [ "background": PaulBackground.red, "transitionIn": TransitionEffect.dissolveIn(duration: 0.3), "transitionOut": TransitionEffect.dissolveOut(duration: 0.3) ]))
        queue.enqueue(DuneNodeParams("Kiss", [ "transitionIn": TransitionEffect.dissolveIn(duration: 0.3), "transitionOut": TransitionEffect.fadeOut(duration: 2.0) ]))
        queue.enqueue(DuneNodeParams("Ornithopter", [ "dayMode": DuneLightMode.night, "scenery": SceneryType.sietch, "transitionIn": TransitionEffect.fadeIn(duration: 2.0) ]))
        queue.enqueue(DuneNodeParams("Flight", [ "dayMode": DuneLightMode.night, "duration": 30.0, "transitionOut": TransitionEffect.fadeOut(duration: 2.0) ]))
        
        engine.addEventObserver(self)

        guard let item = queue.dequeueFirst() else {
            return
        }

        if let currentNode = findNode(item.name) {
            currentNode.params = item.params
            setNodeActive(item.name, true)
        }
    }
    
    
    override func onDisable() {
        queue.empty()
        engine.removeEventObserver(self)
    }
    
    override func render(_ screenBuffer: PixelBuffer) {
        // Render nodes from intro
        buffer.clearBuffer()

        nodes.filter { $0.isActive }.forEach { node in
            node.render(buffer)
        }
        
        buffer.copyPixels(to: screenBuffer, offset: 24 * screenBuffer.width)
    }
    
    
    func onEvent(_ source: String, _ e: DuneEvent) {
        if !self.isActive || !self.isChildNode(source) {
            return
        }
        
        setNodeActive(source, false)
        
        guard let nextItem = queue.dequeueFirst() else {
            engine.sendEvent(self, .nodeEnded)
            return
        }
        
        if let nextNode = findNode(nextItem.name) {
            nextNode.params = nextItem.params
            setNodeActive(nextItem.name, true)
        }
    }
}
