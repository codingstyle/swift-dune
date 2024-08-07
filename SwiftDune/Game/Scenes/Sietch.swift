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
    private var skySprite: Sprite?
    private var characterSprite: Sprite?
    
    private var currentTime: TimeInterval = 0.0
    private let engine = DuneEngine.shared
    
    private var currentRoom: SietchRoom = .room8
    private var markers: Dictionary<Int, RoomCharacter> = [:]
    private var duration: TimeInterval = 0.0
    private var character: DuneCharacter = .none
    
    private let waterInitialRadius = DunePoint(15, 3)
    private var waterRadius = DunePoint(15, 3)
    private var waterRadiusAnimation: DuneAnimation<DunePoint>?
    private let waterCenter = DunePoint(175, 95)
    
    private var fadeIn: Bool = false
    
    init() {
        super.init("Sietch")
    }
    
    
    override func onEnable() {
        sietchScenery = Scenery("SIET.SAL")
        skySprite = Sprite("SKY.HSQ")
        
        sietchScenery?.characters = markers
        
        if character != .none {
            characterSprite = Sprite(character.rawValue)
        }
        
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
        skySprite = nil
        characterSprite = nil
        markers = [:]
        currentRoom = .entrance
        currentTime = 0.0
        character = .none
        waterRadiusAnimation = nil
        waterRadius = DunePoint(15, 3)
        fadeIn = false
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

        if let fadeIn = params["fadeIn"] {
            self.fadeIn = fadeIn as! Bool
        }
    }
    
    
    override func update(_ elapsedTime: TimeInterval) {
        currentTime += elapsedTime
        
        if duration != 0.0 && currentTime > duration {
            engine.sendEvent(self, .nodeEnded)
        }
        
        if let waterRadiusAnimation = waterRadiusAnimation {
            let interpolatedRadius = waterRadiusAnimation.interpolate(currentTime)
            waterRadius = waterInitialRadius + interpolatedRadius
        }
    }
    
    
    override func render(_ buffer: PixelBuffer) {
        guard let sietchScenery = sietchScenery,
              let skySprite = skySprite else {
            return
        }
        
        let intermediateFrameBuffer = engine.intermediateFrameBuffer
        
        intermediateFrameBuffer.clearBuffer()
        
        if currentRoom == .entrance {
            if contextBuffer.tag != 0x0001 {
                // Apply sky gradient with blue palette
                skySprite.setAlternatePalette(1)
                
                for x: Int16 in stride(from: 0, to: 320, by: 40) {
                    skySprite.drawFrame(0, x: x, y: 0, buffer: contextBuffer)
                    skySprite.drawFrame(1, x: x, y: 20, buffer: contextBuffer)
                    skySprite.drawFrame(2, x: x, y: 40, buffer: contextBuffer)
                    skySprite.drawFrame(3, x: x, y: 60, buffer: contextBuffer)
                }

                contextBuffer.tag = 0x0001
            }
            
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
        
        var fx: SpriteEffect {
            if fadeIn && currentTime < 2.0 {
                return .fadeIn(start: 0.0, duration: 2.0, current: currentTime)
            }
            
            return .none
        }

        if currentTime < 0.1 {
            engine.palette.stash()
        }
        
        buffer.clearBuffer()
        intermediateFrameBuffer.render(to: buffer, effect: fx)
    }
}
