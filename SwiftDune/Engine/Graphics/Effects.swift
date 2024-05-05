//
//  Effects.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 03/12/2023.
//

import Foundation


enum SpriteEffect {
    case none
    case fadeIn(start: Double, duration: Double, current: Double)
    case fadeOut(end: Double, duration: Double, current: Double)
    case flipIn(start: Double, duration: Double, current: Double)
    case flipOut(end: Double, duration: Double, current: Double)
    case pixelate(end: Double, duration: Double, current: Double)
    case zoom(start: Double, duration: Double, current: Double, from: DuneRect, to: DuneRect)
    case transform(offset: UInt8 = 0, flipX: Bool = false, flipY: Bool = false, scale: Double = 1.0)
}


struct Effects {
    static func fade(sourceBuffer: PixelBuffer, destBuffer: PixelBuffer, progress: CGFloat, offset: Int = 0) {
        let opacity = UInt32(255.0 * (1.0 - Math.clampf(progress, 0.0, 1.0)))
        let frameSize = destBuffer.frameSize
        var i = 0
        
        while i < frameSize {
            let src = sourceBuffer.rawPointer[i]
            let r = (src & 0xFF)
            let g = (src & 0xFF00) >> 8
            let b = (src & 0xFF0000) >> 16
            destBuffer.rawPointer[i] = (
                0xFF000000 |
                (b - min(opacity, b)) << 16 |
                (g - min(opacity, g)) << 8 |
                (r - min(opacity, r))
            )
            i += 1
        }
    }
    
        
    static func flip(sourceBuffer: PixelBuffer, destBuffer: PixelBuffer, progress: CGFloat, offset: Int = 0) {
        let fHeight = CGFloat(sourceBuffer.height)
        let rowSize = sourceBuffer.width
        let rowSizeInBytes = sourceBuffer.width * 4
        let flipHeight = Int(fHeight * progress)
        let y0 = (sourceBuffer.height - flipHeight) / 2
        let y1 = (y0 + flipHeight)
        
        var yDest = y0
        
        while yDest < y1 {
            let ySrc = Int(fHeight * (Double(yDest - y0) / Double(flipHeight)))
            _ = memcpy(destBuffer.rawPointer + (yDest * rowSize) + offset, sourceBuffer.rawPointer + (ySrc * rowSize), rowSizeInBytes)
            yDest += 1
        }
    }
    
    
    static func pixelate(sourceBuffer: PixelBuffer, destBuffer: PixelBuffer, progress: CGFloat, offset: Int = 0) {
        let maxPixelation = 8
        let pixelation = Int(ceil(Math.clampf(progress, 0.0, 1.0) * CGFloat(maxPixelation)))
        sourceBuffer.copyPixels(to: destBuffer)
        
        if pixelation <= 1 {
            return
        }
        
        let frameSize = Int(sourceBuffer.frameSize)
        let rowSize = Int(sourceBuffer.width)
        
        var n = 0
        
        while n < frameSize {
            let x = Int(n % rowSize)
            let y = Int(n / rowSize)
            
            let x2 = x - (x % pixelation)
            let y2 = y - (y % pixelation)
            let j = y2 * rowSize + x2
            
            memcpy(destBuffer.rawPointer + n, destBuffer.rawPointer + j, 4)
            n += 1
        }
    }
    
    
    static func zoom(sourceBuffer: PixelBuffer, destBuffer: PixelBuffer, sourceRect: DuneRect) {
        let xScale = CGFloat(destBuffer.width) / CGFloat(sourceRect.width)
        let yScale = CGFloat(destBuffer.height) / CGFloat(sourceRect.height)
        
        var y = 0
        
        while y < destBuffer.height {
            var x = 0
            
            while x < destBuffer.width {
                let sourceX = Int(CGFloat(sourceRect.x) + CGFloat(x) / xScale)
                let sourceY = Int(CGFloat(sourceRect.y) + CGFloat(y) / yScale)
                
                // Ensure we don't go out of bounds
                guard sourceX < destBuffer.width, sourceY < destBuffer.height else {
                    continue
                }

                let sourceIndex = sourceY * destBuffer.width + sourceX
                let destinationIndex = y * destBuffer.width + x

                // Copy the pixel from sourceBuffer to destinationBuffer
                destBuffer.rawPointer[destinationIndex] = sourceBuffer.rawPointer[sourceIndex]
                
                x += 1
            }
            
            y += 1
        }

    }
}
