//
//  Metrics.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 02/03/2024.
//

import Foundation


enum LogLevel {
    case debug
    case info
    case warn
    case error
}


class Logger {
    private var metrics: [(Double, Double)] = []
    private let maxEntries: Int = 500
    private let metricsQueue = DispatchQueue(label: "com.dune.logger.queue")
    private let loggingQueue = DispatchQueue(label: "com.dune.metrics.queue")
    
    
    func log(_ level: LogLevel, _ s: String) {
        loggingQueue.async {
            print(s)
        }
    }
    
    
    func addMetric(_ value: Double, at time: TimeInterval) {
        metricsQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            metrics.append((time, value))
            
            if metrics.count > maxEntries {
                metrics.removeFirst()
            }
        }
    }
    
    
    func getLastMetrics() -> [(Double, Double)] {
        var result: [(Double, Double)] = []
        
        metricsQueue.sync {
            result = metrics.suffix(maxEntries)
        }
        
        return result
    }
}
