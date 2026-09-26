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
    private var waterDropSound: Sound?
    
    private var currentRoom: SietchRoom = .room8
    private var markers: Dictionary<Int, RoomCharacter> = [:]
    /// Character numbers in the room (World.peopleInRoom); when set they
    /// replace `markers`, placed by the original marker rule.
    private var people: [Int]?
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
        
        waterDropSound = Sound("SD4.HSQ", player: engine.audioPlayer)
      
        // Room 8 is the intro/gameplay sietch record whose marker assignment
        // is decoded in the original scene script: Harah and Stilgar occupy
        // marker slots 6 and 9. Keep explicit caller markers authoritative.
        if markers.isEmpty && currentRoom == .room8 && people == nil {
            markers = [6: .harah, 9: .stilgar]
        }
        applyPeople()
        sietchScenery?.characters = markers

        if character != .none {
            characterSprite = Sprite(character.resourceName)
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
    
    
    private func applyPeople() {
        guard let people = people, let scenery = sietchScenery,
              currentRoom.rawValue < scenery.rooms.count else { return }
        let assignment = World.shared.markerAssignment(people: people,
                                                       markers: scenery.rooms[currentRoom.rawValue].markerCount)
        markers = assignment.compactMapValues { RoomCharacter(rawValue: World.persFrame($0)) }
        scenery.characters = markers
    }


    override func onDisable() {
        people = nil
        sietchScenery = nil
        sky = nil
        characterSprite = nil
        waterDropSound = nil
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
            self.contextBuffer.tag = 0
        }
        
        if let markers = params["markers"] {
            self.markers = markers as! Dictionary<Int, RoomCharacter>
            sietchScenery?.characters = self.markers
        }

        if let people = params["people"] as? [Int] {
            self.people = people
            applyPeople()
        }

        if let duration = params["duration"] {
            self.duration = duration as! TimeInterval
        }
        
        if let character = params["character"] {
            self.character = character as! DuneCharacter
            characterSprite = self.character == .none ? nil : Sprite(self.character.resourceName)
        }
      
        if let lightMode = params["lightMode"] {
            self.lightMode = lightMode as! DuneLightMode
        }
    }
    
    
    override func update(_ elapsedTime: TimeInterval) {
        if currentRoom == .water && currentTime == 0.0 && !(waterDropSound!.isPlaying) {
            engine.audioPlayer.play(waterDropSound!)
        }
      
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
