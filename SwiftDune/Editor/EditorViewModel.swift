//
//  EditorViewModel.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 11/10/2023.
//

import Foundation
import CoreGraphics
import AppKit

@MainActor
class EditorViewModel: ObservableObject {
    private var engine = DuneEngine.shared
    
    @Published var sprite: Sprite?
    private var selectedSpriteAnimationIndex = -1
    private var selectedSpriteFrameIndex = 0
    private var isSpriteAnimation = false
    
    @Published var dialogue: Sentence?
    @Published var music: Music?
    @Published var sound: Sound?
    @Published var video: Video?
    private var isVideoPlaying = false
    
    @Published var palette: [NSColor] = []
    @Published var selectedPaletteIndex = -1
    
    @Published var gameFont: GameFont?
    @Published var largeFont: LargeFont?
    
    @Published var globe: Globe?

    @Published var scenery: Scenery?

    @Published var spriteImage: NSImage?
    @Published var tick: UInt64 = 0
    
    private var timer: Timer?
    private var currentTime: Double = 0.0
    
    private var renderBitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: 320,
        pixelsHigh: 200,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 320 * 4,
        bitsPerPixel: 32
    )!
    
    private var buffer = PixelBuffer(width: 320, height: 200)

    var resourceTypes: [ResourceType] = [
        .music,
        .globe,
        .sprite,
        .font,
        .spriteWithoutPalette,
        .sentence
    ]
    
    
    init() {
        self.timer = Timer.scheduledTimer(withTimeInterval: 1.0 / engine.frameRate, repeats: true) { [weak self] timer in
            self?.updateLoop()
        }
    }
    
    
    deinit {
        self.timer?.invalidate()
        self.timer = nil
    }
    
    
    func loadResource(_ selection: EditorSelection) {
        music = nil
        sprite = nil
        dialogue = nil
        sound = nil
        spriteImage = nil
        globe = nil
        
        self.stopAnimation()
        self.stopVideo()
        
        if selection.resourceType == .sprite || selection.resourceType == .spriteWithoutPalette {
            sprite = Sprite(selection.resourceName)
            selectedPaletteIndex = -1
            selectedSpriteFrameIndex = 0

            if selection.resourceType == .sprite {
                palette = engine.palette.allColors()
            }

            clearBuffer()
            updateSpriteFrame(selectedSpriteFrameIndex)
            
            // sprite!.saveAs(selection.resourceName + ".DEC")
        } else if selection.resourceType == .sentence {
            dialogue = Sentence(selection.resourceName)
        } else if selection.resourceType == .sound {
            sound = Sound(selection.resourceName)
            sound!.dumpInfo()
            engine.audioPlayer.play(sound!)
        } else if selection.resourceType == .music {
            music = Music(selection.resourceName)
        } else if selection.resourceType == .scene {
            scenery = Scenery(selection.resourceName)
        } else if selection.resourceType == .video {
            video = Video(selection.resourceName)
            video!.setPalette()
            palette = engine.palette.allColors()
            self.startVideo()
        } else if selection.resourceType == .globe {
            clearBuffer()
            
            globe = Globe()
            globe!.render(buffer: buffer)
            
            palette = engine.palette.allColors()

            blitBuffer()
        } else if selection.resourceType == .font {
            clearBuffer()

            if selection.resourceName == "DUNECHAR.HSQ" {
                gameFont = GameFont()
                gameFont!.paletteIndex = 32
                
                var s = String()

                for i in 32..<91 {
                    s.append(String(UnicodeScalar(UInt8(i))))
                }
                
                gameFont!.render(s, rect: DuneRect(2, 10, 316, 10), buffer: buffer, style: .normal)
                gameFont!.render(s, rect: DuneRect(2, 50, 316, 10), buffer: buffer, style: .small)

                s.removeAll()
                
                for i in 91..<128 {
                    s.append(String(UnicodeScalar(UInt8(i))))
                }

                gameFont!.render(s, rect: DuneRect(2, 30, 316, 10), buffer: buffer, style: .normal)
                gameFont!.render(s, rect: DuneRect(2, 70, 316, 10), buffer: buffer, style: .small)

                //gameFont!.render("I am Duke Leto Atreides, your father.", x: 10, y: 10, buffer: buffer)
            } else if selection.resourceName == "GENERIC.HSQ" {
                largeFont = LargeFont()
                largeFont!.setPalette()
                
                largeFont!.render("ABCDEFGHIJKLMNOP", x: 10, y: 10, buffer: buffer)
                largeFont!.render("QRSTUVWXYZ012345", x: 10, y: 30, buffer: buffer)
                largeFont!.render("abcdefghijklmnop", x: 10, y: 50, buffer: buffer)
                largeFont!.render("qrstuvwxyz012345", x: 10, y: 70, buffer: buffer)
            }
            
            blitBuffer()
            //saveBufferAsPNG(to: "BUFFER.PNG")
        }
    }
    
    
    func clearBuffer() {
        buffer.clearBuffer(transparent: true)
    }
    
    
    func blitBuffer() {
        guard let imageBuffer = renderBitmap.bitmapData else {
            return
        }
        
        memset(imageBuffer, 0, renderBitmap.bytesPerRow * renderBitmap.pixelsHigh)
        
        var n = 0
        
        while n < buffer.frameSizeInBytes {
            let destIndex = n * 4
            let paletteIndex = buffer.rawPointer[n]
            
            if paletteIndex == 0 {
                n += 1
                continue
            }
            
            let color = engine.palette.rawPointer[Int(paletteIndex)]
            imageBuffer[destIndex + 3] = UInt8((color & 0xFF000000) >> 24)
            imageBuffer[destIndex + 2] = UInt8((color & 0xFF0000) >> 16)
            imageBuffer[destIndex + 1] = UInt8((color & 0xFF00) >> 8)
            imageBuffer[destIndex + 0] = UInt8(color & 0xFF)
            
            n += 1
        }
        
        spriteImage = NSImage(cgImage: renderBitmap.cgImage!, size: .zero)
    }
    
    
    func saveBufferAsPNG(to fileName: String) {
        let downloadsDirectory = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        let fileURL = downloadsDirectory.appendingPathComponent(fileName)
  
        let dataToWrite = Data(renderBitmap.representation(using: .png, properties: [:])!)
        
        do {
            try dataToWrite.write(to: fileURL)
            print("File saved successfully at: \(fileURL.path)")
        } catch {
            print("Error saving file: \(error.localizedDescription)")
        }
    }
    
    
    func updateSpriteFrame(_ index: Int) {
        stopAnimation()

        let frameInfo = self.sprite!.frame(at: index)
        
        selectedSpriteFrameIndex = index
        if frameInfo.height > 1 {
            self.sprite!.drawFrame(UInt16(index), x: 0, y: 0, buffer: buffer)
        } else {
            for y: Int16 in 0..<30 {
                self.sprite!.drawFrame(UInt16(index), x: 0, y: y, buffer: buffer)
            }
        }
        blitBuffer()
        
        // saveBufferAsPNG(to: "\(self.sprite!.fileName)_\(index).PNG")
    }
    
    
    func startAnimation(_ index: Int) {
        self.selectedSpriteAnimationIndex = index
        self.isSpriteAnimation = true
    }
    
    func stopAnimation() {
        self.selectedSpriteAnimationIndex = -1
        self.isSpriteAnimation = false
    }
    
    
    func updateSpriteAnimation() {
        if self.timer == nil {
            return
        }
        
        guard let sprite = sprite, self.selectedSpriteAnimationIndex >= 0 else {
            return
        }

        self.clearBuffer()
        sprite.drawAnimation(UInt16(self.selectedSpriteAnimationIndex), buffer: buffer, time: currentTime)
        self.blitBuffer()
    }
    
    
    func updateSpritePalette(_ index: Int) {        
        if index == -1 {
            sprite!.setPalette()
        } else {
            sprite!.setAlternatePalette(index)
        }
        
        palette = engine.palette.allColors()
        updateSpriteFrame(selectedSpriteFrameIndex)
    }
    
    
    func updateSceneryRoom(_ index: Int) {
        guard let scenery = scenery else {
            return
        }
        
        self.clearBuffer()
        scenery.drawRoom(index, buffer: buffer)
        self.blitBuffer()
    }
    
    
    func updateLoop() {
        currentTime += 1.0 / engine.frameRate
        
        if let _ = self.video {
            if self.isVideoPlaying {
                self.updateVideoFrame()
            }
        }
        
        if let _ = self.sprite {
            if self.isSpriteAnimation {
                self.updateSpriteAnimation()
            }
        }
        
        if let _ = self.globe {
            self.moveGlobe(.right)
        }
    }
    
    
    func startVideo() {
        self.clearBuffer()
        self.blitBuffer()
        self.isVideoPlaying = true
    }
    
    
    func stopVideo() {
        self.isVideoPlaying = false
    }
    
    
    func moveToNextVideoFrame() {
        if !self.video!.isFrameEmpty() {
            self.video!.renderFrame(buffer)
        }
    }
    
    
    func updateVideoFrame(_ index: Int = -1) {
        if index != -1 {
            self.video!.setFrameIndex(index)
            self.video!.renderFrame(buffer)
            palette = engine.palette.allColors()
        } else {
            if !self.video!.hasFrames() {
                print("Video is finished")
                self.stopVideo()
                return
            }

            if !self.video!.isFrameEmpty() {
                self.video!.renderFrame(buffer)
                palette = engine.palette.allColors()
            }
            
            self.video?.moveToNextFrame()
        }

        self.blitBuffer()
    }
    
    
    func moveGlobe(_ move: GlobeMove) {
        self.globe!.move(move)
        self.globe!.render(buffer: buffer)
        self.blitBuffer()
    }
}
