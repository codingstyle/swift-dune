//
//  Effects.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 03/12/2023.
//

import Foundation


enum TransitionEffect {
    case none
    case fadeIn(duration: Double)
    case fadeOut(duration: Double)
    case flipIn(duration: Double)
    case flipOut(duration: Double)
    case dissolveIn(duration: Double)
    case dissolveOut(duration: Double)
    case pixelate(duration: Double)
    case zoom(duration: Double, from: DuneRect, to: DuneRect)
  
    var duration: Double {
        switch self {
        case .fadeIn(let duration):
            return duration
        case .fadeOut(let duration):
            return duration
        case .flipIn(let duration):
            return duration
        case .flipOut(let duration):
            return duration
        case .dissolveIn(let duration):
            return duration
        case .dissolveOut(let duration):
            return duration
        case .pixelate(let duration):
            return duration
        case .zoom(let duration, _, _):
            return duration
        case .none:
            return 0.0
        }
    }
  
  
    func spriteEffect(start: Double, end: Double, currentTime: Double) -> SpriteEffect {
        switch self {
        case .fadeIn(let duration):
            return .fadeIn(start: start, duration: duration, current: currentTime)
        case .fadeOut(let duration):
            return .fadeOut(end: end, duration: duration, current: currentTime)
        case .flipIn(let duration):
            return .flipIn(start: start, duration: duration, current: currentTime)
        case .flipOut(let duration):
            return .flipOut(end: end, duration: duration, current: currentTime)
        case .dissolveIn(let duration):
            return .dissolveIn(start: start, duration: duration, current: currentTime)
        case .dissolveOut(let duration):
            return .dissolveOut(end: end, duration: duration, current: currentTime)
        case .pixelate(let duration):
            return .pixelate(end: duration, duration: duration, current: currentTime)
        case .zoom(let duration, let from, let to):
            return .zoom(start: end - duration, duration: duration, current: currentTime, from: from, to: to)
        case .none:
            return .none
        }
    }
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
    static func fade(progress: CGFloat, startIndex: Int = 0, endIndex: Int = 255) {
        let engine = DuneEngine.shared
        
        engine.palette.unstash()
        
        let clampedProgress = Math.clampf(progress, 0.0, 1.0)
        var n = startIndex
        
        while n < endIndex &+ 1 {
            let src = engine.palette.rawPointer[n]
            
            let r = (src & 0xFF)
            let g = (src >> 8) & 0xFF
            let b = (src >> 16) & 0xFF
            
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
        let height = Int16(destBuffer.height - Int(yOffset))

        while y < height {
            var x: Int = 0

            while x < destBuffer.width {
                var n = 0
                
                while n < pixelCount {
                    let pt = pixelTransitionOffsets[n]
                    let index = Int(320 * (y &+ Int(pt.y)) &+ (x &+ Int(pt.x)))
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
        let y1 = (y0 &+ flipHeight)
        
        var yDest = y0
        
        while yDest < y1 {
            let ySrc = Int(fHeight * (Double(yDest - y0) / Double(flipHeight)))
            _ = memcpy(destBuffer.rawPointer + (yDest * rowSize) + offset, sourceBuffer.rawPointer + (ySrc * rowSize), rowSizeInBytes)
            yDest += 1
        }
    }
    
    
    static func pixelate(sourceBuffer: PixelBuffer, destBuffer: PixelBuffer, progress: CGFloat, yOffset: Int = 0) {
      let maxPixelation = 16.0
        var pixelation = Int(round(Math.clampf(progress, 0.0, 1.0) * maxPixelation))
        
        if pixelation <= 1 {
            pixelation = 1
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
          
            destBuffer.rawPointer[n + (yOffset * rowSize)] = sourceBuffer.rawPointer[j]
            n += 1
        }
    }
    
    
    static func zoom(sourceBuffer: PixelBuffer, destBuffer: PixelBuffer, sourceRect: DuneRect, yOffset: Int = 0) {
        var y = yOffset
        let destHeight = Int16(destBuffer.height - Int(yOffset * 2))
        let destY = Int16(destBuffer.height - Int(yOffset))

        let xScale = CGFloat(destBuffer.width) / CGFloat(sourceRect.width)
        let yScale = CGFloat(destHeight) / CGFloat(sourceRect.height)
        let sourceRectX = CGFloat(sourceRect.x)
        let sourceRectY = CGFloat(sourceRect.y)

        while y < destY {
            var x = 0
            let sourceY = Int(sourceRectY + CGFloat(y - yOffset) / yScale)
          
            guard sourceY < destBuffer.height else {
                continue
            }

            let sourceIndex = sourceY * destBuffer.width
            let destinationIndex = y * destBuffer.width

            while x < destBuffer.width {
                let sourceX = Int(sourceRectX + CGFloat(x) / xScale)
                
                // Ensure we don't go out of bounds
                guard sourceX < destBuffer.width else {
                    continue
                }

                // Copy the pixel from sourceBuffer to destinationBuffer
                destBuffer.rawPointer[destinationIndex + x] = sourceBuffer.rawPointer[sourceIndex + sourceX]
                
                x += 1
            }
            
            y += 1
        }

    }
}
