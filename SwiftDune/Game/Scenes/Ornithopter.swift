//
//  OrnyTakeOff.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 20/02/2024.
//

import Foundation

enum OrnithopterFlightMode: Int {
    case landed = 0
    case takingOff
    case landing
}


struct Animate {
    static func value<T: FixedWidthInteger>(from: T, to: T, startTime: Double, duration: Double, currentTime: Double) -> T {
        let ratio = (currentTime - startTime) / duration
        
        if ratio < 0 && from is any UnsignedInteger {
            return from
        }
        
        let value = T(ratio * (Double(to) - Double(from)))
        return Math.clamp(value, from, to)
    }
}


final class Ornithopter: DuneNode {
    private var contextBuffer = PixelBuffer(width: 320, height: 152)

    private var ornySprite: Sprite?
    private var skySprite: Sprite?
    private var scenery: Scenery?
    
    private var currentTime: Double = 0.0
    private let engine = DuneEngine.shared
    
    private var feetFrameIndex: UInt16 = 2
    private var wingFrameIndex: UInt16 = 8
    private var animationStartTime: Double = 0.0
    
    private var ornyX: Int16 = 68
    private var ornyY: Int16 = 56

    init() {
        super.init("Ornithopter")
    }
    
    
    override func onEnable() {
        ornySprite = Sprite("ORNYTK.HSQ")
        scenery = Scenery("SIET.SAL")
        skySprite = Sprite("SKY.HSQ")
    }
    
    
    override func onDisable() {
        ornySprite = nil
        scenery = nil
        skySprite = nil
        
        currentTime = 0.0
        ornyX = 68
        ornyY = 56
        feetFrameIndex = 2
        wingFrameIndex = 8
    }
    
    
    override func update(_ elapsedTime: Double) {
        currentTime += elapsedTime

        wingFrameIndex = Animate.value(from: 8, to: 22, startTime: 0.0, duration: 1.2, currentTime: currentTime)
        feetFrameIndex = Animate.value(from: 2, to: 7, startTime: 1.8, duration: 0.4, currentTime: currentTime)
        ornyX = 68 - Animate.value(from: 0, to: 100, startTime: 2.0, duration: 0.6, currentTime: currentTime)
        ornyY = 56 - Animate.value(from: 0, to: 152, startTime: 2.0, duration: 0.6, currentTime: currentTime)
    }
    
    
    override func render(_ buffer: PixelBuffer) {
        drawBackground(buffer)
        drawOrnithopter(ornyX, ornyY, buffer)
    }

    
    private func drawBackground(_ buffer: PixelBuffer) {
        if contextBuffer.tag == 0x01 {
            contextBuffer.render(to: buffer, effect: .none)
            return
        }
        
        guard let scenery = scenery,
              let skySprite = skySprite else {
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

        scenery.drawRoom(0, buffer: contextBuffer)
        
        contextBuffer.render(to: buffer, effect: .none)
        contextBuffer.tag = 0x01
    }
    
    
    private func drawOrnithopter(_ x: Int16, _ y: Int16, _ buffer: PixelBuffer) {
        guard let ornySprite = ornySprite else {
            return
        }
        
        ornySprite.setPalette()
        ornySprite.drawFrame(1, x: x + 87, y: y + 33, buffer: buffer)
        ornySprite.drawFrame(0, x: x + 81, y: y + 3, buffer: buffer)
        ornySprite.drawFrame(feetFrameIndex, x: x + 85, y: y + 53, buffer: buffer)
        ornySprite.drawFrame(wingFrameIndex, x: x, y: y, buffer: buffer)
    }
}
