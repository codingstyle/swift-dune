//
//  Effects.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 03/12/2023.
//

import Foundation


enum TransitionEffect {
    case none
    case fadeIn
    case fadeOut
    case flipIn
    case flipOut
    case dissolveIn
    case dissolveOut
    case pixelate
    case zoom
}


enum SpriteEffect {
    case none
    case fadeIn(start: Double, duration: Double, current: Double)
    case fadeOut(end: Double, duration: Double, current: Double)
    case flipIn(start: Double, duration: Double, current: Double)
    case flipOut(end: Double, duration: Double, current: Double)
    case dissolveIn(start: Double, duration: Double, current: Double)
    case dissolveOut(end: Double, duration: Double, current: Double)
    case pixelate(end: Double, duration: Double, current: Double)
    case zoom(start: Double, duration: Double, current: Double, from: DuneRect, to: DuneRect)
    case transform(offset: UInt8 = 0, flipX: Bool = false, flipY: Bool = false, scale: Double = 1.0)
}


struct Effects {
    static func fade(progress: CGFloat) {
        let engine = DuneEngine.shared
        
        engine.palette.unstash()
        
        let clampedProgress = Math.clampf(progress, 0.0, 1.0)
        var n = 0
        
        while n < 256 {
            let src = engine.palette.rawPointer[n]
            
            let r = (src & 0xFF)
            let g = (src & 0xFF00) >> 8
            let b = (src & 0xFF0000) >> 16
            
            let dR = UInt32(CGFloat(r) * clampedProgress)
            let dG = UInt32(CGFloat(g) * clampedProgress)
            let dB = UInt32(CGFloat(b) * clampedProgress)
            
            engine.palette.rawPointer[n] = (0xFF000000 | (dB << 16) | (dG << 8) | dR)
            n += 1
        }
    }
    
    
    static let pixelTransitionOffsets: [DunePoint] = [
        DunePoint(1, 1), DunePoint(0, 3), DunePoint(3, 2), DunePoint(2, 0),
        DunePoint(0, 1), DunePoint(2, 3), DunePoint(0, 0), DunePoint(1, 2),
        DunePoint(3, 0), DunePoint(1, 3), DunePoint(2, 1), DunePoint(3, 3),
        DunePoint(2, 2), DunePoint(1, 0), DunePoint(3, 1), DunePoint(0, 2)
    ]
    
    
    static func dissolve(destBuffer: PixelBuffer, progress: CGFloat, yOffset: Int) {
        let pixelCount = Int(round(16.0 * Math.clampf(progress, 0.0, 1.0)))
        
        var y = yOffset
        let height = Int16(destBuffer.height - Int(yOffset * 2))

        while y < height {
            var x: Int = 0

            while x < destBuffer.width {
                var n = 0
                
                while n < pixelCount {
                    let pt = pixelTransitionOffsets[n]
                    let index = Int(320 * (y + Int(pt.y)) + (x + Int(pt.x)))
                    destBuffer.rawPointer[index] = 0
                    
                    n += 1
                }
                
                x += 4
            }
            
            y += 4
        }
    }
    
        
    static func flip(sourceBuffer: PixelBuffer, destBuffer: PixelBuffer, progress: CGFloat, offset: Int = 0) {
        let fHeight = CGFloat(sourceBuffer.height)
        let rowSize = sourceBuffer.width
        let rowSizeInBytes = sourceBuffer.rowSizeInBytes
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
            
            destBuffer.rawPointer[n] = destBuffer.rawPointer[j]
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
