//
//  GameViewModel.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 09/10/2023.
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

final class GameViewModel: ObservableObject, DuneEngineDelegate {
    @Published var isRunning = false
    @Published var fpsChartData: [GameFPSData] = []
    
    let engine = DuneEngine.shared

    init() {
        engine.delegate = self
        engine.rootNode.attachNode(Main())
        engine.rootNode.setNodeActive("Main", true)

        /*engine.rootNode.attachNode(Fresk())
        engine.rootNode.attachNode(UI())
        engine.rootNode.setNodeActive("Fresk", true)
        engine.rootNode.setNodeActive("UI", true)*/
    }
    
    
    deinit {
        engine.delegate = nil
    }
    
    
    func renderDidFinish() {
        DispatchQueue.main.sync {
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
        let date = NSDate()
        let fileName = "DuneCapture_\(date.timeIntervalSince1970).png"
        engine.saveBufferToPNG(as: fileName, scale: 3)
    }
}
