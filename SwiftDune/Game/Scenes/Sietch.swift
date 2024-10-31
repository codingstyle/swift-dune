//
//  Sietch.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 25/02/2024.
//

import Foundation

enum SietchRoom: Int {
    case entrance = 0
    case room1 = 1
    case room2 = 2
    case room3 = 3
    case room4 = 4
    case room5 = 5
    case room6 = 6
    case room7 = 7
    case room8 = 8
    case room9 = 9
    case room10 = 10
    case room11 = 11
    case water = 12
    case garden = 13
}

final class Sietch: DuneNode {
    private var contextBuffer = PixelBuffer(width: 320, height: 152)
    
    private var sietchScenery: Scenery?
    private var sky: Sky?
    private var characterSprite: Sprite?
    
    private var currentRoom: SietchRoom = .room8
    private var markers: Dictionary<Int, RoomCharacter> = [:]
    private var character: DuneCharacter = .none
    
    private let waterInitialRadius = DunePoint(15, 3)
    private var waterRadius = DunePoint(15, 3)
    private var waterRadiusAnimation: DuneAnimation<DunePoint>?
    private let waterCenter = DunePoint(175, 95)
  
    private var lightMode: DuneLightMode = .day

    private let desertRect = DuneRect(0, 78, 320, 74)
    private let desertPaletteIndex = 63
    
    init() {
        super.init("Sietch")
    }
    
    
    override func onEnable() {
        sietchScenery = Scenery("SIET.SAL")
        sky = Sky()
        
        sietchScenery?.characters = markers
        
        if currentRoom == .water {
            waterRadius = waterInitialRadius
            waterRadiusAnimation = DuneAnimation<DunePoint>(
                from: DunePoint.zero,
                to: DunePoint(320, 22),
                startTime: 0.0,
                endTime: 3.0
            )
        }
    }
    
    
    override func onDisable() {
        sietchScenery = nil
        sky = nil
        characterSprite = nil
        markers = [:]
        currentRoom = .entrance
        currentTime = 0.0
        character = .none
        waterRadiusAnimation = nil
        waterRadius = waterInitialRadius
        contextBuffer.tag = 0x00
        contextBuffer.clearBuffer()
        lightMode = .day
    }
    
    
    override func onParamsChange() {
        if let room = params["room"] {
            self.currentRoom = room as! SietchRoom
        }
        
        if let markers = params["markers"] {
            self.markers = markers as! Dictionary<Int, RoomCharacter>
        }

        if let duration = params["duration"] {
            self.duration = duration as! TimeInterval
        }
        
        if let character = params["character"] {
            self.character = character as! DuneCharacter
        }
      
        if let lightMode = params["lightMode"] {
            self.lightMode = lightMode as! DuneLightMode
        }
    }
    
    
    override func update(_ elapsedTime: TimeInterval) {
        currentTime += elapsedTime
        
        if let waterRadiusAnimation = waterRadiusAnimation {
            let interpolatedRadius = waterRadiusAnimation.interpolate(currentTime)
            waterRadius = waterInitialRadius + interpolatedRadius
        }
    }
    
    
    override func render(_ buffer: PixelBuffer) {
        guard let sietchScenery = sietchScenery,
              let sky = sky else {
            return
        }
        
        let intermediateFrameBuffer = engine.intermediateFrameBuffer
        
        intermediateFrameBuffer.clearBuffer()
        
        if currentRoom == .entrance {
            if contextBuffer.tag != 0x0001 {
                // Apply sky gradient with blue palette
                sky.lightMode = lightMode
                sky.render(contextBuffer)

                contextBuffer.tag = 0x0001
            }

            Primitives.fillRect(desertRect, desertPaletteIndex, contextBuffer)
          
            contextBuffer.render(to: intermediateFrameBuffer, effect: .none)
        }
        
        sietchScenery.drawRoom(currentRoom.rawValue, buffer: intermediateFrameBuffer)
        
        
        // Water drop animation
        if currentRoom == .water {
            Primitives.drawEllipse(waterCenter, waterRadius, intermediateFrameBuffer)
        }
        
        // Character rendering
        if let characterSprite = characterSprite {
            characterSprite.drawAnimation(0, buffer: intermediateFrameBuffer, time: currentTime)
        }
        
        buffer.clearBuffer()
        intermediateFrameBuffer.render(to: buffer)
    }
}
