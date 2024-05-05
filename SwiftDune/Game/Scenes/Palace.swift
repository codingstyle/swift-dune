//
//  Palace.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 11/02/2024.
//

import Foundation

enum PalaceRoom: Int {
    case porch = 0
    case diningRoom = 1
    case bedroom = 2
    case bedroomEmpty = 3
    case armory = 4
    case command = 5
    case commandHalfLit = 6
    case commandFullLit = 7
    case suitRoomFull = 8
    case suitRoomEmpty = 9
    case balcony = 10
    case stairs = 11
    case corridor = 12
    case darkHall = 13
    case garden = 14
}

final class Palace: DuneNode {
    private var contextBuffer = PixelBuffer(width: 320, height: 152)
    
    private var palaceScenery: Scenery?
    private var skySprite: Sprite?
    private var characterSprite: Sprite?

    private var currentTime: Double = 0.0
    private let engine = DuneEngine.shared
    
    private var currentRoom: PalaceRoom = .stairs
    private var markers: Dictionary<Int, RoomCharacter> = [:]
    private var duration: Double = 0.0
    private var character: DuneCharacter = .none
    private var zoomRect: DuneRect?
    
    init() {
        super.init("Palace")
    }
    
    
    override func onEnable() {
        palaceScenery = Scenery("PALACE.SAL")
        skySprite = Sprite("SKY.HSQ")
        
        engine.palette.clear()
        palaceScenery?.characters = markers
        
        if character != .none {
            characterSprite = Sprite(character.rawValue)
        }
    }
    
    
    override func onDisable() {
        palaceScenery = nil
        skySprite = nil
        characterSprite = nil
        
        markers = [:]
        currentRoom = .stairs
        currentTime = 0.0
        contextBuffer.tag = 0x0000
        zoomRect = nil
    }
    
    
    override func onParamsChange() {
        if let room = params["room"] {
            self.currentRoom = room as! PalaceRoom
        }
        
        if let markers = params["markers"] {
            self.markers = markers as! Dictionary<Int, RoomCharacter>
        }

        if let duration = params["duration"] {
            self.duration = duration as! Double
        }
        
        if let character = params["character"] {
            self.character = character as! DuneCharacter
        }
        
        if let zoom = params["zoom"] {
            self.zoomRect = zoom as? DuneRect
        }
    }
    
    
    override func update(_ elapsedTime: Double) {
        currentTime += elapsedTime
        
        if duration != 0.0 && currentTime > duration {
            engine.sendEvent(self, .nodeEnded)
        }
    }
    
    
    override func render(_ buffer: PixelBuffer) {
        guard let palaceScenery = palaceScenery,
              let skySprite = skySprite else {
            return
        }
        
        buffer.clearBuffer()
        skySprite.setAlternatePalette(1)

        var fx: SpriteEffect {
            if let zoomRect = zoomRect {
                return .zoom(start: 0, duration: 9999.0, current: currentTime, from: zoomRect, to: zoomRect)
            } else {
                return .none
            }
        }

        // Apply sky gradient with blue palette
        if currentRoom == .porch || currentRoom == .balcony {
            if contextBuffer.tag != 0x0001 {
                for x: Int16 in stride(from: 160, to: 320, by: 40) {
                    skySprite.drawFrame(0, x: x, y: 0, buffer: contextBuffer)
                    skySprite.drawFrame(1, x: x, y: 20, buffer: contextBuffer)
                    skySprite.drawFrame(2, x: x, y: 40, buffer: contextBuffer)
                    skySprite.drawFrame(3, x: x, y: 60, buffer: contextBuffer)
                }

                palaceScenery.drawRoom(currentRoom.rawValue, buffer: contextBuffer)
                contextBuffer.tag = 0x0001
            }
            
            contextBuffer.render(to: buffer, effect: fx)
        } else if currentRoom == .stairs {
            if contextBuffer.tag != 0x0002 {
                for x: Int16 in stride(from: 0, to: 200, by: 40) {
                    skySprite.drawFrame(4, x: x, y: 0, buffer: contextBuffer)
                    skySprite.drawFrame(5, x: x, y: 30, buffer: contextBuffer)
                    skySprite.drawFrame(6, x: x, y: 60, buffer: contextBuffer)
                    skySprite.drawFrame(7, x: x, y: 90, buffer: contextBuffer)
                }
                
                palaceScenery.drawRoom(currentRoom.rawValue, buffer: contextBuffer)
                contextBuffer.tag = 0x0002
            }
            
            contextBuffer.render(to: buffer, effect: fx)
        }
        
        if let characterSprite = characterSprite {
            characterSprite.drawAnimation(0, buffer: buffer, time: currentTime)
        }
    }
}
