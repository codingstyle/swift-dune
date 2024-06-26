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

final class DuneEngine {
    static let shared = DuneEngine()
    
    var palette = Palette()
    var audioPlayer = AudioPlayer()
    var keyboard = Keyboard()
    
    var isRunning: Bool = false
    var onRender: ((_ buffer: PixelBuffer) -> Void)?
    var onPostRender: (() -> Void)?
    var gameTime: TimeInterval = 0.0
    var fpsMetrics = Metrics()

    let frameRate = 60.0
    let frameSizeInBytes = 256000 // 320 * 200 * 4
    let rowSizeInBytes = 1280 // 320 * 4

    private var screenBuffers: [PixelBuffer] = []
    private var offscreenBufferIndex = 1
    
    var rootNode: DuneNode = DuneNode("Root")
    
    private var eventObservers: [DuneEventObserver] = []
    
    init() {
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

        /*let activeNodes = nodesMap.values.filter { $0.isActive }
        activeNodes.forEach { node in
            node.onDisable()
            node.onEnable()
        }*/
        
        isRunning = true
    }

    
    func pause() {
        isRunning = false
    }
    
    
    func stop() {
        isRunning = false
    }
    

    func gameLoop() {
        print("Starting game loop...")
        
        var lastTime = ProcessInfo.processInfo.systemUptime

        while true {
            if !isRunning {
                break
            }

            let currentTime = ProcessInfo.processInfo.systemUptime
            let elapsedTime = currentTime - lastTime
            gameTime += elapsedTime

            processInput()

            update(elapsedTime)
            render()

            let renderingTime = ProcessInfo.processInfo.systemUptime - currentTime
            lastTime = currentTime
            
            let sleepTime = (1.0 / frameRate) - renderingTime
            
            if sleepTime > 0.0 {
                usleep(useconds_t(sleepTime * 1000.0))
            }

            fpsMetrics.addMetric(1.0 / (renderingTime + (sleepTime > 0.0 ? sleepTime : 0.0)), at: gameTime)
            onPostRender?()
        }
    }
    
    
    func processInput() {
        // TODO: Process input (mouse)
        
        // Process keyboard input
        while let key = keyboard.keysPressed.dequeueFirst() {
            rootNode.onKey(key)
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
            onRender?(currentOffscreenBuffer)
        }

        // Swap the pixel buffers
        offscreenBufferIndex = (offscreenBufferIndex + 1) % screenBuffers.count
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

    
    func loadSound(_ fileName: String) -> Sound? {
        do {
            let sound = Sound(fileName, engine: self)
            try sound.load()
            return sound
        } catch {
            print("Error loading sound: \(fileName) = \(error)")
        }
        
        return nil
    }
    
    
    func loadVideo(_ fileName: String) -> Video? {
        let video = Video(fileName, engine: self)
        return video
    }
    
    
    func loadScenery(_ fileName: String) -> Scenery? {
        let scenery = Scenery(fileName, engine: self)
        return scenery
    }
    
    
    func loadSprite(_ fileName: String, updatePalette: Bool = true) -> Sprite {
        let sprite = Sprite(fileName)
        
        if updatePalette {
            sprite.setPalette()
        }

        return sprite
    }
    
    
    func loadGameFont() -> GameFont {
        let font = GameFont()
        return font
    }

    
    func loadLargeFont() -> LargeFont {
        let font = LargeFont(engine: self)
        return font
    }


    func loadSentence(_ fileName: String) -> Sentence? {
        let sentence = Sentence(fileName)
        return sentence
    }
    
    
    func saveBufferToPNG(as fileName: String, scale: Int = 1) {
        let currentOffscreenBuffer = screenBuffers[offscreenBufferIndex]
        currentOffscreenBuffer.saveToPNG(as: fileName, scale: scale)
    }
}


extension CGImage {
    func resize(to size: CGSize) -> CGImage? {
        let width: Int = Int(size.width)
        let height: Int = Int(size.height)

        let bytesPerPixel = self.bitsPerPixel / self.bitsPerComponent
        let destBytesPerRow = width * bytesPerPixel


        guard let colorSpace = self.colorSpace else { return nil }
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: self.bitsPerComponent, bytesPerRow: destBytesPerRow, space: colorSpace, bitmapInfo: self.alphaInfo.rawValue) else { return nil }

        context.interpolationQuality = .none
        context.draw(self, in: CGRect(x: 0, y: 0, width: width, height: height))

        return context.makeImage()
    }
}
