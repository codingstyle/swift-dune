//
//  DuneEngine.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 21/08/2023.
//

import Foundation
import AppKit
import Darwin
import UniformTypeIdentifiers

protocol DuneEngineDelegate {
    func renderDidFinish()
}

final class DuneEngine {
    static let shared = DuneEngine()
    
    var palette = Palette()
    var audioPlayer = AudioPlayer()
    var keyboard = Keyboard()
    var mouse = Mouse()
    var renderer = Renderer()
    var logger = Logger()
    
    var delegate: DuneEngineDelegate?

    var isRunning: Bool = false

    let frameRate = 60.0

    private var gameTime: TimeInterval = 0.0
    private var currentTime: TimeInterval = 0.0
    private var lastTime: TimeInterval = 0.0

    var rootNode: DuneNode = DuneNode("Root")
    
    private var eventObservers: [DuneEventObserver] = []

    var intermediateFrameBuffer: PixelBuffer
    
    private var screenBuffers: [PixelBuffer] = []
    private var offscreenBufferIndex = 1

    var currentScreenBuffer: PixelBuffer {
        return screenBuffers[offscreenBufferIndex]
    }
    
    init() {
        intermediateFrameBuffer = PixelBuffer(width: 320, height: 200)
        
        screenBuffers.append(PixelBuffer(width: 320, height: 200))
        screenBuffers.append(PixelBuffer(width: 320, height: 200))
    }

    
    func run() {
        isRunning = true

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.gameLoop()
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
    

    func gameLoop() {
        logger.log(.info, "Starting game loop...")
        
        lastTime = ProcessInfo.processInfo.systemUptime

        while true {
            if !isRunning {
                break
            }

            currentTime = ProcessInfo.processInfo.systemUptime
            let elapsedTime = currentTime - lastTime
            gameTime += elapsedTime

            processInput()

            update(elapsedTime)
            render()
        }
    }
    
    
    func processInput() {
        // Process mouse clicks
        while let clickEvent = mouse.mouseClicks.dequeueFirst() {
            rootNode.onClick(clickEvent)
        }
        
        // Process keyboard input
        while let keyEvent = keyboard.keysPressed.dequeueFirst() {
            rootNode.onKey(keyEvent)
        }
    }
    
    
    func update(_ elapsedTime: TimeInterval) {
        rootNode.update(elapsedTime)
    }
    
    
    func render() {
        // Prepare buffer
        let currentOffscreenBuffer = screenBuffers[offscreenBufferIndex]

        currentOffscreenBuffer.clearBuffer()
        rootNode.render(currentOffscreenBuffer)
        
        // Sends update to the front
        DispatchQueue.main.sync {
            renderer.update(currentOffscreenBuffer)
        }

        // Swap the pixel buffers
        offscreenBufferIndex = (offscreenBufferIndex + 1) % screenBuffers.count
        
        let renderingTime = ProcessInfo.processInfo.systemUptime - currentTime
        lastTime = currentTime
        
        // Pause until next frame
        let sleepTime = (1.0 / frameRate) - renderingTime
        
        if sleepTime > 0.0 {
            usleep(useconds_t(sleepTime * 1000.0))
        }

        logger.addMetric(1.0 / (renderingTime + (sleepTime > 0.0 ? sleepTime : 0.0)), at: gameTime)
        
        delegate?.renderDidFinish()
    }
    
    
    func sendEvent(_ source: DuneNode, _ event: DuneEvent) {
        for observer in eventObservers {
            observer.onEvent(source.name, event)
        }
    }
    
    
    func addEventObserver(_ observer: DuneEventObserver) {
        eventObservers.append(observer)
    }
    
    
    func removeEventObserver(_ observer: DuneEventObserver) {
        if let index = eventObservers.firstIndex(where: { $0 === observer }) {
            eventObservers.remove(at: index)
        }
    }
    
    
    func exitProgram(_ message: String?) {
        stop()
        
        if let message = message {
            DispatchQueue.main.sync {
                // Close all open windows
                for window in NSApplication.shared.windows {
                    window.close()
                }
                
                // Show the alert
                let alert = NSAlert()
                alert.messageText = "Dune"
                alert.informativeText = message
                alert.alertStyle = .informational
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
        }
        
        exit(1)
    }
}
