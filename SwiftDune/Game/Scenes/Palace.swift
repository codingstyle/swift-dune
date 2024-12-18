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
    
    private var currentRoom: PalaceRoom = .stairs
    private var markers: Dictionary<Int, RoomCharacter> = [:]
    private var character: DuneCharacter = .none
    private var zoomRect: DuneRect?
    private var dayMode: DuneLightMode = .day
    
    private var transitionIn: TransitionEffect = .none
    private var transitionOut: TransitionEffect = .none

    init() {
        super.init("Palace")
    }
    
    
    override func onEnable() {
        palaceScenery = Scenery("PALACE.SAL")
        sky = Sky()
        
        engine.palette.clear()
        palaceScenery?.characters = markers
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
            engine.sendEvent(self, .nodeEnded)
        }
    }
    
    
    override func render(_ buffer: PixelBuffer) {
        guard let palaceScenery = palaceScenery,
              let sky = sky else {
            return
        }
        
        let intermediateFrameBuffer = engine.intermediateFrameBuffer
        
        intermediateFrameBuffer.clearBuffer()
        buffer.clearBuffer()

        // TODO: improve this according to day time
        if currentRoom == .stairs && dayMode == .sunrise {
            let sunriseProgress = Math.clampf((currentTime - 2.0) / 3.0, 0.0, 1.0)
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
                sky.render(contextBuffer, width: 320, at: 0, type: .narrow)
                palaceScenery.drawRoom(currentRoom.rawValue, buffer: contextBuffer)
                contextBuffer.tag = 0x0001
            }

            contextBuffer.render(to: intermediateFrameBuffer, effect: fx)
        } else if currentRoom == .stairs {
            sky.render(intermediateFrameBuffer, width: 200, at: 0, type: .large)
            palaceScenery.drawRoom(currentRoom.rawValue, buffer: intermediateFrameBuffer)

            // Fade on palace
            if dayMode == .sunrise {
                if currentTime > 1.0 {
                    palaceScenery.setPalette(currentRoom.rawValue)
                    engine.palette.stash()
                }

                let sunriseProgress = Math.clampf((currentTime - 2.0) / 3.0, 0.0, 1.0)
                Effects.fade(progress: sunriseProgress, startIndex: 112, endIndex: 127)

                if currentTime == 0.0 {
                    engine.palette.stash()
                }
            }
        }
        
        if let characterSprite = characterSprite {
            characterSprite.drawAnimation(0, buffer: intermediateFrameBuffer, time: currentTime)
        }
        
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
