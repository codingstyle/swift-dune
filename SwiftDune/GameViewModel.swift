//
//  GameViewModel.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 09/10/2023.
//

import Foundation
import AppKit
import CoreGraphics

struct GameFPSData: Identifiable {
    var id = UUID()
    var time: Double
    var fps: Double
}

final class GameViewModel: ObservableObject {
    @Published var isRunning = false
    @Published var fpsChartData: [GameFPSData] = []
    
    var engine = DuneEngine.shared

    init() {
        engine.rootNode.attachNode(Main())
        engine.rootNode.setNodeActive("Main", true)

        /*engine.rootNode.attachNode(Fresk())
        engine.rootNode.attachNode(UI())
        engine.rootNode.setNodeActive("Fresk", true)
        engine.rootNode.setNodeActive("UI", true)*/

        engine.onPostRender = self.onPostRender
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
        engine.saveBufferToFile(as: fileName, scale: 3)
    }
    
    private func onPostRender() {
        DispatchQueue.main.sync {
            fpsChartData = engine.fpsMetrics.getLastMetrics().map {
                GameFPSData(time: $0, fps: $1)
            }
        }
    }
}
