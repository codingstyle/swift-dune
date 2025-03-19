//
//  Flight.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 11/05/2024.
//

import Foundation

/*
 
 Sprites from DUNES.HSQ
 0-7: dunes
 8-11: rocks
 12-15: vegetation
 16: Arrakeen
 17: Sietch
 18: Smugglers village
 19: fort
 
*/


struct FlightTerrainSprite {
    var spriteIndex: UInt16
    var animation: DuneAnimation<DunePoint>
    var position: DunePoint = .zero
    var scale: Double = 0.0
    var markForRemoval: Bool = false
}


struct FlightVanishingLine {
    var start: DunePoint
    var end: DunePoint
    
    init(start: DunePoint = DunePoint(160, 70), radius: UInt16 = 300, angle: Double) {
        self.start = start

        let xOffset = Double(radius) * cos(angle)
        let yOffset = Double(radius) * sin(angle)
        
        self.end = DunePoint(start.x + Int16(xOffset), start.y + Int16(yOffset))
    }
}

final class Flight: DuneNode {
    private var contextBuffer = PixelBuffer(width: 320, height: 152)

    private var dunesSprite: Sprite?
    private var sky: Sky?
    private var dayMode: DuneLightMode = .day
    
    private var frameCount: UInt32 = 0
    private var debugVanishingLines = false
    
    private var flightSprites: [FlightTerrainSprite] = []
    private let vanishingLines: [FlightVanishingLine] = [
      FlightVanishingLine(angle: 0.5 * Math.PI / 12.0),
      FlightVanishingLine(angle: 1.0 * Math.PI / 12.0),
      FlightVanishingLine(angle: 2.0 * Math.PI / 12.0),
      FlightVanishingLine(angle: 3.0 * Math.PI / 12.0),
      FlightVanishingLine(angle: 4.0 * Math.PI / 12.0),
      FlightVanishingLine(angle: 5.0 * Math.PI / 12.0),
      FlightVanishingLine(angle: 6.0 * Math.PI / 12.0),
      FlightVanishingLine(angle: 7.0 * Math.PI / 12.0),
      FlightVanishingLine(angle: 8.0 * Math.PI / 12.0),
      FlightVanishingLine(angle: 9.0 * Math.PI / 12.0),
      FlightVanishingLine(angle: 10.0 * Math.PI / 12.0),
      FlightVanishingLine(angle: 11.0 * Math.PI / 12.0),
      FlightVanishingLine(angle: 11.5 * Math.PI / 24.0),
    ]
    private let terrainRect = DuneRect(0, 78, 320, 74)
    
    init() {
        super.init("Flight")
    }
    
    
    override func onEnable() {
        dunesSprite = Sprite("DUNES.HSQ")
        sky = Sky()
    }
    
    
    override func onDisable() {
        dunesSprite = nil
        sky = nil
    }
    
    
    override func onParamsChange() {
        if let dayMode = params["dayMode"] {
            self.dayMode = dayMode as! DuneLightMode
        }
        
        if let durationParam = params["duration"] {
            self.duration = durationParam as! TimeInterval
        }
    }
    
    
    override func update(_ elapsedTime: TimeInterval) {
        currentTime += elapsedTime
        
        if currentTime > duration {
            EventManager.nodeEndedEvent.notify(NodeEventData(self.name))
            return
        }
        
        // 1. Randomize a sprite in 0-12 range
        // 2. Choose a path
        if (frameCount % 60) == 0 {
            var i = 0
          
            let evenIndexes = [0, 2, 4, 6, 8, 10, 12]
            let oddIndexes = [1, 3, 5, 7, 9, 11]
            var indexes = (frameCount % 2 == 0 ? evenIndexes : oddIndexes)
            let indexCount = 5
          
            while i < indexCount {
                let spriteIndex = UInt16(round(CGFloat(Math.random(0, 700)) / 100.0))
                let randomIndex = Int(round(CGFloat(Math.random(0, (indexes.count - 1) * 100)) / 100.0))
                let pathIndex = indexes.remove(at: randomIndex)
                let path = vanishingLines[pathIndex]
              
                flightSprites.append(FlightTerrainSprite(
                  spriteIndex: spriteIndex,
                  animation: DuneAnimation<DunePoint>(from: path.start, to: path.end, startTime: currentTime, endTime: currentTime + 2.0, timing: .cubic)
                ))
              
              i += 1
            }
            
            for var sprite in flightSprites {
                let anim = sprite.animation
                let pt = anim.interpolate(currentTime)
                
                if pt.y < terrainRect.y + Int16(terrainRect.height) {
                    sprite.position = pt
                    sprite.scale = 0.0
                } else {
                    sprite.markForRemoval = true
                }
            }
            
            flightSprites.removeAll { $0.markForRemoval == true }
            
            flightSprites.sort { a, b in
              a.scale > b.scale
            }
        }
        
        frameCount += 1
    }
    
    
    override func render(_ buffer: PixelBuffer) {
        drawBackground(buffer)
        
        guard let dunesSprite = dunesSprite else {
            return
        }
      
        for var sprite in flightSprites {
            let anim = sprite.animation
            let pt = anim.interpolate(currentTime)
          
            if pt.y < terrainRect.y {
                continue
            }

            if anim.endValue.y != anim.startValue.y {
              sprite.scale = 1.2 * Double(pt.y - 80) / 72.0
            }
          
            let spriteInfo = dunesSprite.frame(at: Int(sprite.spriteIndex))
            let x = pt.x - Int16(Double(spriteInfo.width) * sprite.scale)

            dunesSprite.drawFrame(
                sprite.spriteIndex,
                x: x,
                y: pt.y,
                buffer: buffer,
                effect: .transform(scale: sprite.scale)
            )
        }
      
        if debugVanishingLines {
            for path in vanishingLines {
              Primitives.drawLine(path.start, path.end, 3, buffer)
            }
        }
    }
    
    
    private func drawBackground(_ buffer: PixelBuffer) {
        if contextBuffer.tag == dayMode.asInt {
            contextBuffer.render(to: buffer, effect: .none)
            return
        }
        
        guard let sky = sky else {
            return
        }
        
        sky.lightMode = dayMode
        sky.render(contextBuffer)

        Primitives.fillRect(terrainRect, 63, contextBuffer)
        
        contextBuffer.render(to: buffer, effect: .none)
        contextBuffer.tag = dayMode.asInt
    }
}
