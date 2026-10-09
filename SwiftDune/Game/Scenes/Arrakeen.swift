//
//  Bunker.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 26/09/2026.
//

import Foundation

enum ArrakeenRoom: Int {
  case fort = 0
  case building1 = 1
  case building2 = 2
  case building3 = 3
  case entrance = 4
  case prisonCell = 5
  case corridor = 6
  case throne = 7
}


final class Arrakeen: DuneNode {
    private var contextBuffer = PixelBuffer(width: 320, height: 152)

    private var arrakeenScenery: Scenery?
    private var currentRoom: ArrakeenRoom = .throne
    private var markers: Dictionary<Int, RoomCharacter> = [:]
  
    private var transitionIn: TransitionEffect = .none
    private var transitionOut: TransitionEffect = .none

    init() {
        super.init("Arrakeen")
    }
  
    override func onEnable() {
        arrakeenScenery = Scenery("HARK.SAL")
        
        engine.palette.clear()
        arrakeenScenery?.characters = markers
    }
  
  
    override func onDisable() {
        arrakeenScenery = nil
        markers = [:]
        currentRoom = .throne
        currentTime = 0.0
        contextBuffer.tag = 0x0000
    }
  
  
    override func onParamsChange() {
        if let room = params["room"] {
          self.currentRoom = room as! ArrakeenRoom
        }
        
        if let markers = params["markers"] {
          self.markers = markers as! Dictionary<Int, RoomCharacter>
        }
        
        if let transitionInParam = params["transitionIn"] {
          self.transitionIn = transitionInParam as! TransitionEffect
        }
        
        if let transitionOutParam = params["transitionOut"] {
          self.transitionOut = transitionOutParam as! TransitionEffect
        }
    }
  
  
    override func update(_ elapsedTime: TimeInterval) {
      currentTime += elapsedTime
      
      if duration != 0.0 && currentTime > duration {
        EventManager.nodeEndedEvent.notify(NodeEventData(self.name))
      }
    }
    
    
    override func render(_ buffer: PixelBuffer) {
      guard let arrakeenScenery = arrakeenScenery else {
        return
      }
      
      let intermediateFrameBuffer = engine.intermediateFrameBuffer
      
      intermediateFrameBuffer.clearBuffer()
      buffer.clearBuffer()
      
      
      if contextBuffer.tag != 0x0001 {
        arrakeenScenery.drawRoom(currentRoom.rawValue, buffer: contextBuffer)
        contextBuffer.tag = 0x0001
      }
      
      contextBuffer.render(to: intermediateFrameBuffer, effect: .none)
      
      var fxTransition: SpriteEffect {
        switch transitionOut {
          case .dissolveOut:
            return .dissolveOut(end: duration, duration: 0.3, current: currentTime)
          default:
            return .none
        }
      }
      
      intermediateFrameBuffer.render(to: buffer, effect: fxTransition)
    }
}
