//
//  Flight.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 11/05/2024.
//

import Foundation

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
}

final class Flight: DuneNode {
    private var contextBuffer = PixelBuffer(width: 320, height: 152)

    private var dunesSprite: Sprite?
    private var skySprite: Sprite?
    
    private var currentTime: TimeInterval = 0.0
    private var frameCount: UInt32 = 0
    private let engine = DuneEngine.shared
    
    private var flightSprites: [FlightSprite] = []
    private let flightPaths: [FlightPath] = [
        FlightPath(start: DunePoint(110, 80), end: DunePoint(-640, 200)),
        FlightPath(start: DunePoint(120, 80), end: DunePoint(-480, 200)),
        FlightPath(start: DunePoint(130, 80), end: DunePoint(-320, 200)),
        FlightPath(start: DunePoint(140, 80), end: DunePoint(-160, 200)),
        FlightPath(start: DunePoint(150, 80), end: DunePoint(0, 200)),
        FlightPath(start: DunePoint(160, 80), end: DunePoint(160, 200)),
        FlightPath(start: DunePoint(170, 80), end: DunePoint(320, 200)),
        FlightPath(start: DunePoint(180, 80), end: DunePoint(480, 200)),
        FlightPath(start: DunePoint(190, 80), end: DunePoint(640, 200))
    ]
    
    init() {
        super.init("Flight")
    }
    
    
    override func onEnable() {
        dunesSprite = Sprite("DUNES.HSQ")
        skySprite = Sprite("SKY.HSQ")
    }
    
    
    override func onDisable() {
        dunesSprite = nil
        skySprite = nil
    }
    
    
    override func update(_ elapsedTime: TimeInterval) {
        currentTime += elapsedTime
        
        guard let dunesSprite = dunesSprite else {
            return
        }
        
        // 1. Randomize a sprite in 0-12 range
        // 2. Choose a path
        
        if (frameCount % 20) == 0 {
            var i = 0
            
            while i < 3 {
                let index = Math.random(0, 12)
                let pathIndex = Math.random(0, flightPaths.count - 1)
                let path = flightPaths[pathIndex]
                let frameInfo = dunesSprite.frame(at: index)
                let finalHalfWidth = Int16(Double(frameInfo.width) * 1.5 / 2.0)
                
                flightSprites.append(FlightSprite(
                    spriteIndex: UInt16(index),
                    xAnimation: DuneAnimation<Int16>(from: path.start.x, to: path.end.x - finalHalfWidth, startTime: currentTime, endTime: currentTime + 1.0),
                    yAnimation: DuneAnimation<Int16>(from: path.start.y, to: path.end.y, startTime: currentTime, endTime: currentTime + 1.0)
                ))
                
                i += 1
            }
        }
        
        for var sprite in flightSprites {
            let x = sprite.xAnimation.interpolate(currentTime)
            let y = sprite.yAnimation.interpolate(currentTime)
            let scale = 2.0 * Double(y - sprite.yAnimation.startValue) / Double(sprite.yAnimation.endValue - sprite.yAnimation.startValue)
            
            if y < 152 || x > -80 {
                sprite.position = DunePoint(x, y)
                sprite.scale = scale
            } else {
                sprite.markForRemoval = true
            }
        }
        
        flightSprites.removeAll { $0.markForRemoval == true }
        frameCount += 1
    }
    
    
    override func render(_ buffer: PixelBuffer) {
        drawBackground(buffer)
        
        guard let dunesSprite = dunesSprite else {
            return
        }
        
        for sprite in flightSprites.reversed() {
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
        if contextBuffer.tag == 0x01 {
            contextBuffer.render(to: buffer, effect: .none)
            return
        }
        
        guard let skySprite = skySprite else {
            return
        }
        
        skySprite.setAlternatePalette(3)

        for x: Int16 in stride(from: 0, to: 320, by: 40) {
            skySprite.drawFrame(0, x: x, y: 0, buffer: contextBuffer)
            skySprite.drawFrame(1, x: x, y: 20, buffer: contextBuffer)
            skySprite.drawFrame(2, x: x, y: 40, buffer: contextBuffer)
            skySprite.drawFrame(3, x: x, y: 60, buffer: contextBuffer)
        }

        Primitives.fillRect(DuneRect(0, 78, 320, 74), 63, contextBuffer)
        
        contextBuffer.render(to: buffer, effect: .none)
        contextBuffer.tag = 0x01
    }
}
