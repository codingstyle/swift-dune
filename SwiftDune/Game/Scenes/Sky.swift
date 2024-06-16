//
//  Sky.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 08/03/2024.
//

import Foundation

final class Sky {
    private var skySprite: Sprite?
    
    var lightMode: DuneLightMode = .night
    var width: Int16 = 320
 
    init() {
        skySprite = Sprite("SKY.HSQ")
    }
    
    
    func render(_ buffer: PixelBuffer) {
        guard let skySprite = skySprite else {
            return
        }
        
        switch lightMode {
        case .sunrise:
            skySprite.setAlternatePalette(4)
        case .day:
            skySprite.setAlternatePalette(1)
        case .sunset:
            skySprite.setAlternatePalette(6)
        case .night:
            skySprite.setAlternatePalette(3)
        }
        

        for x: Int16 in stride(from: 0, to: width, by: 40) {
            skySprite.drawFrame(0, x: x, y: 0, buffer: buffer)
            skySprite.drawFrame(1, x: x, y: 20, buffer: buffer)
            skySprite.drawFrame(2, x: x, y: 40, buffer: buffer)
            skySprite.drawFrame(3, x: x, y: 60, buffer: buffer)
        }
    }
}
