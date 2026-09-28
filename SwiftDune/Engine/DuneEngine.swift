//
//  DuneEngine.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 21/08/2023.
//

import Foundation
#if os(macOS)
import AppKit
#else
import UIKit
#endif
import Darwin
import UniformTypeIdentifiers


final class DuneEngine {
    static let shared = DuneEngine()
    
    var palette: Palette
    var audioPlayer: AudioPlayer
    var keyboard: Keyboard
    var mouse: Mouse
    var renderer: Renderer
    var logger: Logger

    var isRunning: Bool = false

    let frameRate = 60.0
    let expectedFrameTime: Double = 1.0 / 60.0

    private var gameTime: TimeInterval = 0.0
    private var currentTime: TimeInterval = 0.0
    private var lastTime: TimeInterval = 0.0

    var rootNode: DuneNode

    /// Palettes applied after every node has drawn this frame (the palette
    /// is shared; a backdrop whose colours must win over overlays drawn on
    /// top of it registers here, e.g. the vision dream's VIS.HSQ).
    var finalPalettes: [() -> Void] = []
    
    var intermediateFrameBuffer: PixelBuffer
    
    private var screenBuffers: [PixelBuffer] = []
    private var offscreenBufferIndex = 1

    var currentScreenBuffer: PixelBuffer {
        return screenBuffers[offscreenBufferIndex]
    }
    
    private init() {
        palette = Palette()
        audioPlayer = AudioPlayer()
        keyboard = Keyboard()
        mouse = Mouse()
        renderer = Renderer()
        logger = Logger()

        intermediateFrameBuffer = PixelBuffer(width: 320, height: 200)
        
        screenBuffers.append(PixelBuffer(width: 320, height: 200))
        screenBuffers.append(PixelBuffer(width: 320, height: 200))
      
        rootNode = DuneNode("Root")
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

            autoreleasepool {
                currentTime = ProcessInfo.processInfo.systemUptime
                let elapsedTime = currentTime - lastTime
                gameTime += elapsedTime
                
                DevHarness.shared.tick(gameTime, self)
                processInput()
                
                update(elapsedTime)
                render()
            }
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
        finalPalettes.forEach { $0() }
        finalPalettes.removeAll()
        
        // Sends update to the front
        DispatchQueue.main.sync {
            self.renderer.update(currentOffscreenBuffer)
        }
        
        // Swap the pixel buffers
        offscreenBufferIndex = (offscreenBufferIndex + 1) % screenBuffers.count
        
        let renderingTime = ProcessInfo.processInfo.systemUptime - currentTime
        lastTime = currentTime
        
        // Pause until next frame
        let sleepTime = expectedFrameTime - renderingTime
        
        if sleepTime > 0.0 {
            usleep(useconds_t(sleepTime * 1_000_000.0))
        }
        
        logger.addMetric(1.0 / (renderingTime + (sleepTime > 0.0 ? sleepTime : 0.0)), at: gameTime)
    }
    
    
    func exitProgram(_ message: String?) {
        stop()
        
        #if os(iOS)
        // iOS apps must not quit themselves; show the message and leave the
        // app idle so the user can read it and swipe it away.
        if let message = message {
            logger.log(.error, "exitProgram: \(message)")
            DispatchQueue.main.async {
                let alert = UIAlertController(title: "Dune", message: message, preferredStyle: .alert)
                UIApplication.shared.connectedScenes
                    .compactMap { ($0 as? UIWindowScene)?.keyWindow?.rootViewController }
                    .first?
                    .present(alert, animated: true)
            }
        }
        return
        #else
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
        #endif
    }


    /// Folder for screenshots, dumps and logs: Downloads on macOS, the app's
    /// Documents folder on iOS (visible in the Files app, see Info.plist).
    static var outputDirectory: URL {
        #if os(iOS)
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        #else
        return FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        #endif
    }
}
