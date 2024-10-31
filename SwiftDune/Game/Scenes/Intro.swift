//
//  Intro.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 18/12/2023.
//

import Foundation


struct IntroStep {
    var background: DuneNodeParams?
    var foreground: DuneNodeParams?
    var duration: TimeInterval = 60.0
    var transitionIn: TransitionEffect = .none
    var transitionOut: TransitionEffect = .none
}


final class Intro: DuneNode, DuneEventObserver {
    private var buffer = PixelBuffer(width: 320, height: 152)
    private var queue = Queue<IntroStep>()
    private var currentStep: IntroStep?
  
    private var currentTransition: TransitionEffect?
    private var needsTransition = false
    
    init() {
        super.init("Intro")
        
        attachNode(LogoSwap())
        attachNode(Presents())
        attachNode(Stars())
        attachNode(DuneTitle())
        attachNode(WormCall())
        attachNode(Background())
        attachNode(Character())
        attachNode(Sunrise())
        attachNode(Sietch())
        attachNode(DesertWalk())
        attachNode(Palace())
        attachNode(Kiss())
        attachNode(Attack())
        attachNode(Ornithopter())
        attachNode(Flight())
    }

    override func onEnable() {
        // Intro script
        queue.enqueue(IntroStep(
          background: DuneNodeParams("LogoSwap"),
          duration: 6.03,
          transitionOut: .fadeOut(duration: 2.0)
        ))
        queue.enqueue(IntroStep(
          background: DuneNodeParams("Presents", [ "screen": PresentsScreen.virginPresents ]),
          duration: 3.8,
          transitionIn: .fadeIn(duration: 0.9),
          transitionOut: .fadeOut(duration: 0.9)
        ))
        queue.enqueue(IntroStep(
          background: DuneNodeParams("Presents", [ "screen": PresentsScreen.cryoPresents ]),
          duration: 5.51,
          transitionIn: .fadeIn(duration: 0.9),
          transitionOut: .fadeOut(duration: 0.9)
        ))
        queue.enqueue(IntroStep(
          background: DuneNodeParams("Stars", [ "mode": StarsMode.planetsPan ]),
          duration: 9.84,
          transitionIn: .fadeIn(duration: 7.34),
          transitionOut: .zoom(duration: 0.5, from: DuneRect.fullScreen, to: DuneRect(140, 66, 40, 19))
        ))
        queue.enqueue(IntroStep(
          background: DuneNodeParams("DuneTitle"),
          duration: 16.5,
          transitionIn: .pixelate(duration: 2.0),
          transitionOut: .fadeOut(duration: 2.0)
        ))
        queue.enqueue(IntroStep(
          background: DuneNodeParams("WormCall"),
          duration: 9.41,
          transitionIn: .fadeIn(duration: 1.0),
          transitionOut: .fadeOut(duration: 1.0)
        ))
        queue.enqueue(IntroStep(
          background: DuneNodeParams("Background", [ "backgroundType": BackgroundType.red ]),
          foreground: DuneNodeParams("Character", [ "character": DuneCharacter.paul ]),
          duration: 8.0,
          transitionIn: .fadeIn(duration: 2.0),
          transitionOut: .fadeOut(duration: 2.0)
        ))
        queue.enqueue(IntroStep(
          background: DuneNodeParams("Sunrise", [ "mode": DuneLightMode.sunrise ]),
          duration: 8.0,
          transitionIn: .fadeIn(duration: 2.0)
        ))
        queue.enqueue(IntroStep(
          background: DuneNodeParams("Sunrise", [ "mode": DuneLightMode.day ]),
          foreground: DuneNodeParams("Character", [ "character": DuneCharacter.chani, "animations": [ 0 ] ]),
          duration: 2.0,
          transitionIn: .zoom(duration: 2.0, from: DuneRect(48, 48, 80, 38), to: DuneRect(48, 48, 80, 38))
        ))
        queue.enqueue(IntroStep(
          background: DuneNodeParams("Sunrise", [ "mode": DuneLightMode.day ]),
          foreground: DuneNodeParams("Character", [ "character": DuneCharacter.chani, "animations": [ 0 ] ]),
          duration: 2.5,
          transitionIn: .zoom(duration: 0.25, from: DuneRect(48, 48, 80, 38), to: .fullScreen)
        ))
        queue.enqueue(IntroStep(
          background: DuneNodeParams("Sunrise", [ "mode": DuneLightMode.day ]),
          foreground: DuneNodeParams("Character", [ "character": DuneCharacter.chani, "animations": [ 1, 2 ] ]),
          duration: 2.0
        ))
        queue.enqueue(IntroStep(
          background: DuneNodeParams("Sunrise", [ "mode": DuneLightMode.day, "village": true ]),
          foreground: DuneNodeParams("Character", [ "character": DuneCharacter.liet, "animations": [ 1, 2 ] ]),
          duration: 2.0
        ))
        queue.enqueue(IntroStep(
          background: DuneNodeParams("Sunrise", [ "mode": DuneLightMode.day ]),
          foreground: DuneNodeParams("Character", [ "character": DuneCharacter.chani, "animations": [ 1, 2 ] ]),
          duration: 2.0
        ))
        queue.enqueue(IntroStep(
          background: DuneNodeParams("Background", [ "backgroundType": BackgroundType.desert ]),
          foreground: DuneNodeParams("Character", [ "character": DuneCharacter.paul ]),
          duration: 4.0,
          transitionOut: .fadeOut(duration: 2.0)
        ))
        queue.enqueue(IntroStep(
          background: DuneNodeParams("Sietch", [ "room": SietchRoom.room8, "markers": [
              6: RoomCharacter.harah,
              9: RoomCharacter.stilgar
          ] ] ),
          duration: 4.0,
          transitionIn: .fadeIn(duration: 2.0)
        ))
        queue.enqueue(IntroStep(
          background: DuneNodeParams("Sietch", [ "room": SietchRoom.water ]),
          duration: 4.0
        ))
        queue.enqueue(IntroStep(
          background: DuneNodeParams("Sietch", [ "room": SietchRoom.room8, "markers": [
            6: RoomCharacter.harah,
            9: RoomCharacter.stilgar
          ]]),
          duration: 4.0
        ))
        queue.enqueue(IntroStep(
          background: DuneNodeParams("Sietch", [ "room": SietchRoom.water ]),
          foreground: DuneNodeParams("Character", [ "character": DuneCharacter.stilgar ]),
          duration: 4.0,
          transitionOut: .dissolveOut(duration: 0.3)
        ))
        queue.enqueue(IntroStep(
          background: DuneNodeParams("DesertWalk", [ "dayMode": DuneLightMode.day ]),
          duration: 2.0,
          transitionIn: .dissolveIn(duration: 0.3)
        ))
        queue.enqueue(IntroStep(
          background: DuneNodeParams("Palace", [ "room": PalaceRoom.stairs ]),
          duration: 2.0
        ))
        queue.enqueue(IntroStep(
          background: DuneNodeParams("Palace", [ "room": PalaceRoom.balcony, "markers": [
            4: RoomCharacter.gurney,
            5: RoomCharacter.duncan,
            6: RoomCharacter.thufir,
            7: RoomCharacter.jessica,
            8: RoomCharacter.leto
          ]]),
          duration: 2.0
        ))
        queue.enqueue(IntroStep(
          background: DuneNodeParams("Palace", [ "room": PalaceRoom.balcony, "zoom": DuneRect(75, 45, 84, 40) ]),
          foreground: DuneNodeParams("Character", [ "character": DuneCharacter.leto ]),
          duration: 4.0
        ))
        queue.enqueue(IntroStep(
          background: DuneNodeParams("Palace", [ "room": PalaceRoom.balcony, "zoom": DuneRect(170, 63, 84, 40) ]),
          foreground: DuneNodeParams("Character", [ "character": DuneCharacter.jessica ]),
          duration: 4.0,
          transitionOut: .dissolveOut(duration: 0.3)
        ))
        queue.enqueue(IntroStep(
          background: DuneNodeParams("Background", [ "backgroundType": BackgroundType.red ]),
          foreground: DuneNodeParams("Character", [ "character": DuneCharacter.paul ]),
          duration: 4.0,
          transitionIn: .dissolveIn(duration: 0.3),
          transitionOut: .dissolveOut(duration: 0.3)
        ))
        queue.enqueue(IntroStep(
          background: DuneNodeParams("Sunrise", [ "mode": DuneLightMode.sunset, "fort": true ]),
          duration: 5.0,
          transitionIn: .dissolveIn(duration: 0.3),
          transitionOut: .dissolveOut(duration: 0.3)
        ))
        queue.enqueue(IntroStep(
          background: DuneNodeParams("Background", [ "backgroundType": BackgroundType.baron ]),
          foreground: DuneNodeParams("Character", [ "character": DuneCharacter.baron ]),
          duration: 2.0,
          transitionIn: .dissolveIn(duration: 0.3)
        ))
        queue.enqueue(IntroStep(
          background: DuneNodeParams("Background", [ "backgroundType": BackgroundType.feyd ]),
          foreground: DuneNodeParams("Character", [ "character": DuneCharacter.feyd, "animations": [ 1, 4, 4, 4 ] ]),
          duration: 4.0
        ))
        queue.enqueue(IntroStep(
          background: DuneNodeParams("Background", [ "backgroundType": BackgroundType.baron, "sardaukar": true ]),
          foreground: DuneNodeParams("Character", [ "character": DuneCharacter.baron ]),
          duration: 3.0,
          transitionOut: .dissolveOut(duration: 0.3)
        ))
        queue.enqueue(IntroStep(
          background: DuneNodeParams("Attack"),
          duration: 10.0,
          transitionIn: .dissolveIn(duration: 0.3),
          transitionOut: .dissolveOut(duration: 0.3)
        ))
        queue.enqueue(IntroStep(
          background: DuneNodeParams("Background", [ "backgroundType": BackgroundType.red ]),
          foreground: DuneNodeParams("Character", [ "character": DuneCharacter.paul ]),
          duration: 4.0,
          transitionIn: .dissolveIn(duration: 0.3),
          transitionOut: .dissolveOut(duration: 0.3)
        ))
        queue.enqueue(IntroStep(
          background: DuneNodeParams("Kiss"),
          duration: 10.0,
          transitionIn: .dissolveIn(duration: 0.3),
          transitionOut: .fadeOut(duration: 2.0)
        ))
        queue.enqueue(IntroStep(
          background: DuneNodeParams("Sietch", [ "room": SietchRoom.entrance, "lightMode": DuneLightMode.night ]),
          foreground: DuneNodeParams("Ornithopter", [ "flightMode": OrnithopterFlightMode.takingOff ]),
          duration: 5.0,
          transitionIn: .fadeIn(duration: 2.0)
        ))
        queue.enqueue(IntroStep(
          background: DuneNodeParams("Flight", [ "dayMode": DuneLightMode.night ]),
          duration: 60.0,
          transitionOut: .fadeOut(duration: 2.0)
        ))
         
        engine.addEventObserver(self)

        guard let nextStep = queue.dequeueFirst() else {
            return
        }

        activateStep(nextStep)
    }
  
  
    override func onDisable() {
        queue.empty()
        engine.removeEventObserver(self)
    }
    
  
    override func update(_ elapsedTime: TimeInterval) {
        guard let currentStep = currentStep else { return }

        currentTime += elapsedTime
      
        if currentTime > currentStep.duration {
            onEvent(currentStep.background!.name, .nodeEnded)
            return
        }
      
        if (currentTime < currentStep.transitionIn.duration || currentTime > currentStep.duration - currentStep.transitionOut.duration) {
            if !needsTransition && currentTransition == nil {
              needsTransition = true
            }
          
            if currentTime < currentStep.transitionIn.duration {
                currentTransition = currentStep.transitionIn
            } else if currentTime > currentStep.duration - currentStep.transitionOut.duration {
                currentTransition = currentStep.transitionOut
            }

            return
        } else {
            currentTransition = nil
        }
            
        activeNodes.forEach { node in
            node.update(elapsedTime)
        }
    }
  
    
    override func render(_ screenBuffer: PixelBuffer) {
        guard let currentStep = currentStep else { return }
      
        // Prepare transition by rendering last frame
        if needsTransition {
            buffer.clearBuffer()
            
            activeNodes.forEach { node in
              node.update(0.0)
              node.render(buffer)
            }
          
            engine.palette.stash()
            needsTransition = false
        }

        screenBuffer.clearBuffer()

        // Render transition
        if let transition = currentTransition {
            buffer.render(to: screenBuffer, effect: transition.spriteEffect(start: 0.0, end: currentStep.duration, currentTime: currentTime), y: 24)
            return
        }
      
        // Render nodes from intro
        buffer.clearBuffer()

        activeNodes.forEach { node in
            node.render(buffer)
        }
        
        buffer.copyPixels(to: screenBuffer, offset: 24 * screenBuffer.width)
    }
    
    
    func onEvent(_ source: String, _ e: DuneEvent) {
        if !self.isActive || !self.isChildNode(source) {
            return
        }
        
        disableStep()
      
        guard let nextStep = queue.dequeueFirst() else {
            engine.sendEvent(self, .nodeEnded)
            return
        }
        
        activateStep(nextStep)
    }
  
  
    private func disableStep() {
        guard let currentStep = currentStep else { return }

        if let backgroundNodeConfig = currentStep.background {
            setNodeActive(backgroundNodeConfig.name, false)
        }

        if let foregroundNodeConfig = currentStep.foreground {
            setNodeActive(foregroundNodeConfig.name, false)
        }

        activeNodes = nodes.sorted().filter { $0.isActive }
        buffer.clearBuffer()

        self.currentStep = nil
        currentTime = 0.0
        currentTransition = nil
    }
  
    
    private func activateStep(_ step: IntroStep) {
        // Activate background and foreground nodes
        if let backgroundNodeConfig = step.background {
            if let node = findNode(backgroundNodeConfig.name) {
                node.params = backgroundNodeConfig.params
                node.duration = step.duration
                setNodeActive(backgroundNodeConfig.name, true, .background)
            }
        }
        
        if let foregroundNodeConfig = step.foreground {
            if let node = findNode(foregroundNodeConfig.name) {
                node.params = foregroundNodeConfig.params
                node.duration = step.duration
                setNodeActive(foregroundNodeConfig.name, true, .foreground)
            }
        }

        activeNodes = nodes.sorted().filter { $0.isActive }
        currentStep = step
    }
}
