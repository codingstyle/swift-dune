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
    
    
    func setPalette(gameplayPalette: Bool = false) {
        guard let skySprite = skySprite else {
            return
        }

        func setAlternate(_ index: Int, _ prevIndex: Int = -1, blend: CGFloat = 1.0) {
            if gameplayPalette {
                // dune-re-ref's gameplay path writes SKY.HSQ as 80 colours
                // at 128, followed by the UI tail at 240. Applying the whole
                // 95-colour alternate block at 128 corrupts BALCON colours.
                skySprite.setAlternatePalette(
                    index,
                    prevIndex,
                    blend: blend,
                    sourceOffset: 0,
                    destinationStart: 128,
                    count: 80
                )
                skySprite.setAlternatePalette(
                    index,
                    prevIndex,
                    blend: blend,
                    sourceOffset: 80,
                    destinationStart: 240,
                    count: 15
                )
            } else {
                skySprite.setAlternatePalette(index, prevIndex, blend: blend)
            }
        }
        
        switch lightMode {
        case .sunrise:
            setAlternate(16)
        case .day:
            setAlternate(1)
        case .sunset:
            setAlternate(6)
        case .night:
            setAlternate(3)
        case .custom(let index, let prevIndex, let blend):
            setAlternate(index, prevIndex, blend: blend)
        }

    }
    
    
    func render(
        _ buffer: PixelBuffer,
        width: Int16 = 320,
        at offsetX: Int16 = 0,
        type: SkyType = .narrow,
        gameplayPalette: Bool = false
    ) {
        guard let skySprite = skySprite else {
            return
        }
        
        self.setPalette(gameplayPalette: gameplayPalette)

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
