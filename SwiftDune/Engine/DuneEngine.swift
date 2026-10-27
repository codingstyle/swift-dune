//
//  DuneEngine.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 21/08/2023.
//

import Foundation
import UniformTypeIdentifiers


@MainActor
final class DuneEngine {
    static let shared = DuneEngine()
    
    var palette: Palette
    var audioPlayer: AudioPlayer
    var input: Input
    var renderer: Renderer
    let logger = Logger.shared

    var isRunning: Bool = false

    let frameRate = 60.0
    let expectedFrameTime: Double = 1.0 / 60.0

    private var gameTime: TimeInterval = 0.0
    private var currentTime: TimeInterval = 0.0
    private var lastTime: TimeInterval = 0.0

    var rootNode: DuneNode
    
    var intermediateFrameBuffer: PixelBuffer
    
    private var screenBuffers: [PixelBuffer] = []
    private var offscreenBufferIndex = 1

    var currentScreenBuffer: PixelBuffer {
        return screenBuffers[offscreenBufferIndex]
    }
    
    private init() {
        palette = Palette()
        audioPlayer = AppleAudioPlayer()
        input = Input()
        renderer = Renderer()

        intermediateFrameBuffer = PixelBuffer(width: 320, height: 200)
        
        screenBuffers.append(PixelBuffer(width: 320, height: 200))
        screenBuffers.append(PixelBuffer(width: 320, height: 200))
      
        rootNode = DuneNode("Root")
    }

    
    func run() {
        isRunning = true

        Task { @MainActor in
            await self.gameLoop()
        }
    }

    func reset() {
        isRunning = false

        let activeNodes = rootNode.activeNodes
        
        activeNodes.forEach { node in
            node.onDisable()
            node.onEnable()
        }
        
        isRunning = true
    }

    
    func pause() {
        isRunning = false
    }
    
    
    func stop() {
        isRunning = false
    }
    

    func gameLoop() async {
        logger.log(.info, "Starting game loop...")
        
        lastTime = ProcessInfo.processInfo.systemUptime

        while isRunning {
            autoreleasepool {
                currentTime = ProcessInfo.processInfo.systemUptime
                let elapsedTime = currentTime - lastTime
                gameTime += elapsedTime
                
                input.update(self)
                update(elapsedTime)
            }

            // Sleeping suspends the main actor so AppKit can deliver input between frames.
            await render()
        }
    }
    
    
    func update(_ elapsedTime: TimeInterval) {
        rootNode.update(elapsedTime)
    }
    
    
    func render() async {
        // Prepare buffer
        let currentOffscreenBuffer = screenBuffers[offscreenBufferIndex]
        
        currentOffscreenBuffer.clearBuffer()
        rootNode.render(currentOffscreenBuffer)
        
        renderer.update(currentOffscreenBuffer)
        
        // Swap the pixel buffers
        offscreenBufferIndex = (offscreenBufferIndex + 1) % screenBuffers.count
        
        let renderingTime = ProcessInfo.processInfo.systemUptime - currentTime
        lastTime = currentTime
        
        // Pause until next frame
        let sleepTime = expectedFrameTime - renderingTime
        
        if sleepTime > 0.0 {
            try? await Task.sleep(nanoseconds: UInt64(sleepTime * 1_000_000_000.0))
        }
        
        logger.addMetric(1.0 / (renderingTime + (sleepTime > 0.0 ? sleepTime : 0.0)), at: gameTime)
    }
    
    
    func exitProgram(_ message: String?) {
        stop()
        
        EventManager.appStateChangedEvent.notify(AppStateEventData(.closed, message))
    }
}
