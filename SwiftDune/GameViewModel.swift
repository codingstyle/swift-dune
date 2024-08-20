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


final class GameViewModel: ObservableObject {
    @Published var isRunning = false
    @Published var fpsChartData: [GameFPSData] = []
    @Published var palette: [NSColor] = [NSColor](repeating: NSColor.clear, count: 256)
    
    let engine = DuneEngine.shared

    init() {
        engine.rootNode.attachNode(Main())
        engine.rootNode.setNodeActive("Main", true)

        /*engine.rootNode.attachNode(Fresk())
        engine.rootNode.attachNode(UI())
        engine.rootNode.setNodeActive("Fresk", true)
        engine.rootNode.setNodeActive("UI", true)*/
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
