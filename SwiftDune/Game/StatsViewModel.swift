//
//  StatsViewModel.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 18/08/2024.
//

import Foundation
import AppKit
import CoreGraphics
import SwiftUI

struct GameFPSData: Identifiable {
    var id = UUID()
    var time: Double
    var fps: Double
}

final class StatsViewModel: ObservableObject, DuneEngineDelegate {
    @Published var isRunning = false
    @Published var fpsChartData: [GameFPSData] = []
    @Published var palette: [NSColor] = [NSColor](repeating: NSColor.clear, count: 256)
    
    let engine = DuneEngine.shared

    init() {
        engine.delegate = self
    }
    
    
    deinit {
        engine.delegate = nil
    }
    
    
    func renderDidFinish() {
        DispatchQueue.main.sync {
            isRunning = engine.isRunning
            palette = engine.palette.allColors()
            
            fpsChartData = engine.logger.getLastMetrics().map {
                GameFPSData(time: $0, fps: $1)
            }
        }
    }

    
    func togglePlayPause() {
        if engine.isRunning {
            engine.pause()
        } else {
            engine.run()
        }
        
        isRunning = engine.isRunning
    }
    
    
    func reset() {
        engine.reset()
    }
    
    
    func screenshot() {
        engine.renderer.requestScreenshot(3)
    }
}
