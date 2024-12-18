//
//  Metrics.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 02/03/2024.
//

import Foundation
import os


enum LogLevel {
    case debug
    case info
    case warn
    case error
}


final class Logger {
    private var metrics: [(Double, Double)] = []
    private let maxEntries: Int = 500
    private let metricsQueue = DispatchQueue(label: "com.dune.logger.queue")
    //private let loggingQueue = DispatchQueue(label: "com.dune.metrics.queue")
    private let osLogger = os.Logger.init(subsystem: "com.dune.logger", category: "Engine")

    
    func log(_ level: LogLevel, _ s: String) {
        //loggingQueue.async { [weak self] in
            //guard let self = self else { return }

            switch level {
              case .debug:
                self.osLogger.debug("\(s)")
                break
              case .error:
                self.osLogger.error("\(s)")
                break
              case .info:
                self.osLogger.info("\(s)")
                break
              case .warn:
                self.osLogger.warning("\(s)")
                break
            }
        //}
    }
    
    
    func addMetric(_ value: Double, at time: TimeInterval) {
        metricsQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            metrics.append((time, value))
            
            while metrics.count > maxEntries {
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
