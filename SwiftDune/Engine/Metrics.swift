//
//  Metrics.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 02/03/2024.
//

import Foundation

class Metrics {
    private var metrics: [(Double, Double)] = []
    private let maxEntries: Int = 500
    private let queue = DispatchQueue(label: "com.dunemetrics.queue", attributes: .concurrent)
    
    
    func addMetric(_ value: Double, at time: Double) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            metrics.append((time, value))
            
            if metrics.count > maxEntries {
                metrics.removeFirst()
            }
        }
    }
    
    
    func getLastMetrics() -> [(Double, Double)] {
        var result: [(Double, Double)] = []
        
        queue.sync {
            result = metrics.suffix(maxEntries)
        }
        
        return result
    }
}
