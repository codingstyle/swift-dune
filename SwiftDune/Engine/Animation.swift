//
//  Animation.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 10/05/2024.
//

import Foundation


final class DuneAnimation<T: FixedWidthInteger> {
    var startValue: T
    var endValue: T
    var startTime: Double
    var endTime: Double
    
    init(
        from startValue: T,
        to endValue: T,
        startTime: Double,
        endTime: Double
    ) {
        self.startValue = startValue
        self.endValue = endValue
        self.startTime = startTime
        self.endTime = endTime
    }
    
    
    func interpolate(_ time: Double) -> T {
        let progress = Math.clampf((time - startTime) / (endTime - startTime), 0.0, 1.0)
        return startValue + T(Double(endValue - startValue) * progress)
    }
}


final class DuneCombinedAnimation<T: FixedWidthInteger> {
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
