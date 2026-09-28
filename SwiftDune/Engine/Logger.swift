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
    private let metricsQueue = DispatchQueue(label: "com.dune.metrics.queue")
    private let osLogger = os.Logger.init(subsystem: "com.dune.logger", category: "Engine")

    
    #if os(iOS)
    /// Documents/dune-ios.log, readable from the Files app and AirDrop-able.
    private let logQueue = DispatchQueue(label: "com.dune.logfile.queue")
    private lazy var logHandle: FileHandle? = {
        let url = DuneEngine.outputDirectory.appendingPathComponent("dune-ios.log")
        FileManager.default.createFile(atPath: url.path, contents: nil)
        return try? FileHandle(forWritingTo: url)
    }()
    #endif


    func log(_ level: LogLevel, _ s: String) {
          #if os(iOS)
          logQueue.async { [weak self] in
              let line = "\(Date()) [\(level)] \(s)\n"
              self?.logHandle?.write(line.data(using: .utf8)!)
          }
          #endif
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
