//
//  Sky.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 08/03/2024.
//

import Foundation

enum SkyType {
    case narrow
    case large
}


final class Sky {
    private var skySprite: Sprite?
    
    var lightMode: DuneLightMode = .night
 
    init() {
        skySprite = Sprite("SKY.HSQ")
    }
    
    
    func setPalette() {
        guard let skySprite = skySprite else {
            return
        }
        
        switch lightMode {
        case .sunrise:
            skySprite.setAlternatePalette(16)
        case .day:
            skySprite.setAlternatePalette(1)
        case .sunset:
            skySprite.setAlternatePalette(6)
        case .night:
            skySprite.setAlternatePalette(3)
        case .custom(let index, let prevIndex, let blend):
            skySprite.setAlternatePalette(index, prevIndex, blend: blend)
        }
    }
    
    
    func render(_ buffer: PixelBuffer, width: Int16 = 320, at offsetX: Int16 = 0, type: SkyType = .narrow) {
        guard let skySprite = skySprite else {
            return
        }
        
        self.setPalette()

        var x: Int16 = offsetX

        while x < width {
            if type == .narrow {
                skySprite.drawFrame(0, x: x, y: 0, buffer: buffer)
                skySprite.drawFrame(1, x: x, y: 20, buffer: buffer)
                skySprite.drawFrame(2, x: x, y: 40, buffer: buffer)
                skySprite.drawFrame(3, x: x, y: 60, buffer: buffer)
            } else {
                skySprite.drawFrame(4, x: x, y: 0, buffer: buffer)
                skySprite.drawFrame(5, x: x, y: 30, buffer: buffer)
                skySprite.drawFrame(6, x: x, y: 60, buffer: buffer)
                skySprite.drawFrame(7, x: x, y: 90, buffer: buffer)
            }

            x += 40
        }
    }
}
