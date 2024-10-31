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


struct FlightSprite {
    var spriteIndex: UInt16
    var xAnimation: DuneAnimation<Int16>
    var yAnimation: DuneAnimation<Int16>
    var position: DunePoint = .zero
    var scale: Double = 0.0
    var markForRemoval: Bool = false
}


struct FlightPath {
    var start: DunePoint
    var end: DunePoint
    
    init(start: DunePoint = DunePoint(160, 80), radius: UInt16 = 250, angle: Double) {
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
    
    private var flightSprites: [FlightSprite] = []
    private let flightPaths: [FlightPath] = [
        FlightPath(angle: Math.PI / 12.0),
        FlightPath(angle: 2.0 * Math.PI / 12.0),
        FlightPath(angle: 3.0 * Math.PI / 12.0),
        FlightPath(angle: 4.0 * Math.PI / 12.0),
        FlightPath(angle: 5.0 * Math.PI / 12.0),
        FlightPath(angle: 6.0 * Math.PI / 12.0),
        FlightPath(angle: 7.0 * Math.PI / 12.0),
        FlightPath(angle: 8.0 * Math.PI / 12.0),
        FlightPath(angle: 9.0 * Math.PI / 12.0),
        FlightPath(angle: 10.0 * Math.PI / 12.0),
        FlightPath(angle: 11.0 * Math.PI / 12.0),
    ]
    
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
        /*if let dayMode = params["dayMode"] {
            self.dayMode = dayMode as! DuneLightMode
        }*/
        
        if let durationParam = params["duration"] {
            self.duration = durationParam as! TimeInterval
        }
    }
    
    
    override func update(_ elapsedTime: TimeInterval) {
        currentTime += elapsedTime
        
        if currentTime > duration {
            engine.sendEvent(self, .nodeEnded)
            return
        }
        
        guard let dunesSprite = dunesSprite else {
            return
        }
        
        // 1. Randomize a sprite in 0-12 range
        // 2. Choose a path
        let initialIndexes =  [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
        
        if (frameCount % 10) == 0 {
            var pathIndexes = initialIndexes
            var i = 0
            
            while initialIndexes.count - pathIndexes.count < 3 {
                let index = Math.random(0, 7)
                let randomIndex = Math.random(0, pathIndexes.count - 1)
                let pathIndex = pathIndexes.remove(at: randomIndex)
                let path = flightPaths[pathIndex]
                let frameInfo = dunesSprite.frame(at: index)
                let finalHalfWidth = Int16(Double(frameInfo.width) * 1.5 / 2.0)
                
                flightSprites.append(FlightSprite(
                    spriteIndex: UInt16(index),
                    xAnimation: DuneAnimation<Int16>(from: path.start.x, to: path.end.x - finalHalfWidth, startTime: currentTime, endTime: currentTime + 2.0),
                    yAnimation: DuneAnimation<Int16>(from: path.start.y, to: path.end.y, startTime: currentTime, endTime: currentTime + 2.0)
                ))
                
                i += 1
            }
            
            for var sprite in flightSprites {
                let x = sprite.xAnimation.interpolate(currentTime)
                let y = sprite.yAnimation.interpolate(currentTime)
                let scale = 1.5 * Double(y - sprite.yAnimation.startValue) / Double(sprite.yAnimation.endValue - sprite.yAnimation.startValue)
                
                if y < 152 || x > -80 {
                    sprite.position = DunePoint(x, y)
                    sprite.scale = scale
                } else {
                    sprite.markForRemoval = true
                }
            }
            
            flightSprites.removeAll { $0.markForRemoval == true }
            
            flightSprites.sort { a, b in
                a.yAnimation.interpolate(currentTime) > b.yAnimation.interpolate(currentTime)
            }
        }
        
        frameCount += 1
    }
    
    
    override func render(_ buffer: PixelBuffer) {
        drawBackground(buffer)
        
        guard let dunesSprite = dunesSprite else {
            return
        }
        
        for sprite in flightSprites {
            let y = sprite.yAnimation.interpolate(currentTime)
            let scale = 1.5 * Double(y - sprite.yAnimation.startValue) / Double(sprite.yAnimation.endValue - sprite.yAnimation.startValue)

            dunesSprite.drawFrame(
                sprite.spriteIndex,
                x: sprite.xAnimation.interpolate(currentTime),
                y: y,
                buffer: buffer,
                effect: .transform(scale: scale)
            )
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

        Primitives.fillRect(DuneRect(0, 78, 320, 74), 63, contextBuffer)
        
        contextBuffer.render(to: buffer, effect: .none)
        contextBuffer.tag = dayMode.asInt
    }
}
