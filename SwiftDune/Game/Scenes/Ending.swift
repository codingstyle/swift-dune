//
//  Ending.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 26/09/2026.
//

import Foundation

struct EndingStep {
  var background: DuneNodeParams?
  var foreground: DuneNodeParams?
  var duration: TimeInterval = 60.0
  var transitionIn: TransitionEffect = .none
  var transitionOut: TransitionEffect = .none
}


final class Ending: DuneNode {
    private var buffer = PixelBuffer(width: 320, height: 152)
    private var queue = Queue<EndingStep>()
    private var currentStep: EndingStep?
    
    private var currentTransition: TransitionEffect?
    private var currentTransitionStart: TimeInterval = 0.0
    private var needsTransition = false


    init() {
        super.init("Ending")

        attachNode(Arrakeen())
        attachNode(PaulAndChani())
    }
    
    
    override func onEnable() {
        // Ending script
        queue.enqueue(EndingStep(
          background: DuneNodeParams("Arrakeen", [ "room": ArrakeenRoom.mainHall, "markers": [
            0: RoomCharacter.baron,
            1: RoomCharacter.emperor,
            2: RoomCharacter.feyd,
            3: RoomCharacter.fremen2,
            4: RoomCharacter.fremen2,
            5: RoomCharacter.fremen2,
            6: RoomCharacter.fremen2,
            7: RoomCharacter.fremen2,
            8: RoomCharacter.fremen2,
            9: RoomCharacter.fremen2,
            10: RoomCharacter.stilgar,
            11: RoomCharacter.gurney,
            12: RoomCharacter.thufir,
            13: RoomCharacter.chani,
            14: RoomCharacter.jessica,
            15: RoomCharacter.duncan,
          ] ] ),
          duration: 5.0,
          transitionIn: .fadeIn(duration: 2.0),
          transitionOut: .none
        ))
      
        // Ending script
        queue.enqueue(EndingStep(
          background: DuneNodeParams("Arrakeen", [ "room": ArrakeenRoom.mainHall, "markers": [
            0: RoomCharacter.baron,
            1: RoomCharacter.emperor,
            2: RoomCharacter.feyd,
            3: RoomCharacter.fremen2,
            4: RoomCharacter.fremen2,
            5: RoomCharacter.fremen2,
            6: RoomCharacter.fremen2,
            7: RoomCharacter.fremen2,
            8: RoomCharacter.fremen2,
            9: RoomCharacter.fremen2,
            10: RoomCharacter.stilgar,
            11: RoomCharacter.gurney,
            12: RoomCharacter.thufir,
            13: RoomCharacter.chani,
            14: RoomCharacter.jessica,
            15: RoomCharacter.duncan,
          ] ] ),
          foreground: DuneNodeParams("PaulAndChani"),
          duration: 60.0,
          transitionIn: .none
        ))

      
        EventManager.nodeEndedEvent.addListener(self) { [weak self] nodeData in
          guard let self = self else { return }
          self.onNodeEvent(nodeData)
        }
        
        guard let nextStep = queue.dequeueFirst() else {
          return
        }
        
        activateStep(nextStep)
    }
  
  
    override func onDisable() {
      queue.empty()
      EventManager.nodeEndedEvent.removeListener(self)
    }
    
    
    override func update(_ elapsedTime: TimeInterval) {
      guard let currentStep = currentStep else { return }
      
      currentTime += elapsedTime
      
      if currentTime > currentStep.duration {
        EventManager.nodeEndedEvent.notify(NodeEventData(currentStep.background!.name))
        return
      }
      
      if (currentTime < currentStep.transitionIn.duration || currentTime > currentStep.duration - currentStep.transitionOut.duration) {
        if !needsTransition && currentTransition == nil {
          needsTransition = true
        }
        
        if currentTime < currentStep.transitionIn.duration {
          currentTransition = currentStep.transitionIn
          currentTransitionStart = 0.0
        } else if currentTime > currentStep.duration - currentStep.transitionOut.duration {
          currentTransition = currentStep.transitionOut
          currentTransitionStart = currentStep.duration - currentStep.transitionOut.duration
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
        buffer.render(to: screenBuffer, effect: transition.spriteEffect(start: currentTransitionStart, end: currentStep.duration, currentTime: currentTime), y: 24)
        return
      }
      
      // Render nodes from intro
      buffer.clearBuffer()
      
      activeNodes.forEach { node in
        node.render(buffer)
      }
      
      buffer.copyPixels(to: screenBuffer, offset: 24 * screenBuffer.width)
    }
    
    
    func onNodeEvent(_ e: NodeEventData) {
      if !self.isActive || !self.isChildNode(e.nodeName) {
        return
      }
      
      disableStep()
      
      guard let nextStep = queue.dequeueFirst() else {
        EventManager.nodeEndedEvent.notify(NodeEventData(self.name))
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
    
    
    private func activateStep(_ step: EndingStep) {
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
