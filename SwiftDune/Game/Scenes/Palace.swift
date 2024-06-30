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
    private var sky: Sky?
    private var characterSprite: Sprite?

    private var currentTime: TimeInterval = 0.0
    private let engine = DuneEngine.shared
    
    private var currentRoom: PalaceRoom = .stairs
    private var markers: Dictionary<Int, RoomCharacter> = [:]
    private var duration: TimeInterval = 0.0
    private var character: DuneCharacter = .none
    private var zoomRect: DuneRect?
    private var dayMode: DuneLightMode = .day
    
    init() {
        super.init("Palace")
    }
    
    
    override func onEnable() {
        palaceScenery = Scenery("PALACE.SAL")
        sky = Sky()
        
        engine.palette.clear()
        palaceScenery?.characters = markers
        
        if character != .none {
            characterSprite = Sprite(character.rawValue)
        }
    }
    
    
    override func onDisable() {
        palaceScenery = nil
        sky = nil
        characterSprite = nil
        
        markers = [:]
        currentRoom = .stairs
        currentTime = 0.0
        contextBuffer.tag = 0x0000
        zoomRect = nil
        dayMode = .day
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

        if let dayMode = params["dayMode"] {
            self.dayMode = dayMode as! DuneLightMode
        }
    }
    
    
    override func update(_ elapsedTime: TimeInterval) {
        currentTime += elapsedTime
        
        if duration != 0.0 && currentTime > duration {
            engine.sendEvent(self, .nodeEnded)
        }
    }
    
    
    override func render(_ buffer: PixelBuffer) {
        guard let palaceScenery = palaceScenery,
              let sky = sky else {
            return
        }
        
        buffer.clearBuffer()

        // TODO: improve this according to day time
        if currentRoom == .stairs {
            let sunriseProgress = Math.clampf((currentTime - 1.0) / 2.0, 0.0, 1.0)
            sky.lightMode = .custom(index: 16, prevIndex: 3, blend: sunriseProgress)
        } else {
            sky.lightMode = .day
        }

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
                sky.render(buffer, width: 160, at: 160)
                palaceScenery.drawRoom(currentRoom.rawValue, buffer: contextBuffer)
                contextBuffer.tag = 0x0001
            }
            
            contextBuffer.render(to: buffer, effect: fx)
        } else if currentRoom == .stairs {
            sky.render(buffer, width: 200, at: 0, type: .large)
            
            palaceScenery.drawRoom(currentRoom.rawValue, buffer: buffer)
        }
        
        if let characterSprite = characterSprite {
            characterSprite.drawAnimation(0, buffer: buffer, time: currentTime)
        }
    }
}
