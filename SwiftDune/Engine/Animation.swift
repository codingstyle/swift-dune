//
//  Animation.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 10/05/2024.
//

import Foundation


enum DuneAnimationTiming {
    case linear
    case easeIn
    case square
    case cubic
}


protocol DuneAnimatable {
    static func interpolated(start: Self, end: Self, frameCount: Double, progress: Double) -> Self
}


extension DunePoint: DuneAnimatable {
    static func interpolated(start: DunePoint, end: DunePoint, frameCount: Double, progress: Double) -> DunePoint {
        let step = ((end - start) * round(progress * frameCount)) / frameCount
        return start + step
    }
}


extension Int16: DuneAnimatable {
    static func interpolated(start: Int16, end: Int16, frameCount: Double, progress: Double) -> Int16 {
        let step = Double(end - start) / frameCount
        return start + Int16(round(step * progress * frameCount))
    }
}


extension UInt16: DuneAnimatable {
    static func interpolated(start: UInt16, end: UInt16, frameCount: Double, progress: Double) -> UInt16 {
        let step = Double(end - start) / frameCount
        return start + UInt16(round(step * progress * frameCount))
    }
}


extension Int: DuneAnimatable {
    static func interpolated(start: Int, end: Int, frameCount: Double, progress: Double) -> Int {
        let step = Double(end - start) / frameCount
        return start + Int(floor(step * progress) * frameCount)
    }
}


final class DuneAnimation<T: DuneAnimatable> {
    private let engine = DuneEngine.shared
    
    private var frameCount: Double
    
    var startValue: T
    var endValue: T
    var startTime: TimeInterval
    var endTime: TimeInterval
    var frameRate: Double = 30.0
    var timing: DuneAnimationTiming
    
    init(
        from startValue: T,
        to endValue: T,
        startTime: TimeInterval,
        endTime: TimeInterval,
        timing: DuneAnimationTiming = .linear
    ) {
        self.startValue = startValue
        self.endValue = endValue
        self.startTime = startTime
        self.endTime = endTime
        self.timing = timing
        
        self.frameCount = Double(endTime - startTime) * frameRate
    }
    
    
    func interpolate(_ time: TimeInterval) -> T {
        let elapsedTime = time - startTime
        let totalTime = endTime - startTime
        var progress = 0.0
        
        switch timing {
          case .linear:
            progress = Math.clampf(elapsedTime / totalTime, 0.0, 1.0)
            break
          case .easeIn:
            progress = Math.clampf(1.0 / pow(elapsedTime / totalTime, 2.0), 0.0, 1.0)
            break
          case .square:
            progress = Math.clampf(pow(elapsedTime, 2.0) / totalTime, 0.0, 1.0)
            break
          case .cubic:
            progress = Math.clampf(pow(elapsedTime, 3.0) / totalTime, 0.0, 1.0)
            break
        }
        
        return T.interpolated(
            start: startValue,
            end: endValue,
            frameCount: frameCount,
            progress: progress
        )
    }
}


/*
final class DuneSequenceAnimation<T: DuneAnimatable> {
    var animations: [DuneAnimation<T>]
    
    init(_ animations: [DuneAnimation<T>]) {
        self.animations = animations
    }
    
    func interpolate(_ time: Double) -> T {
        if animations.count > 0 {
            return 0
        }
        
        var i = 0
        
        while i < animations.count {
            if animations[i].startTime <= time && time < animations[i].endTime {
                return animations[i].interpolate(time)
            }
            
            i += 1
        }
        
        return animations.last!.endValue
    }
}
*/
