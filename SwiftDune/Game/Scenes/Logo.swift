//
//  Logo.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 07/10/2023.
//

import Foundation

final class Logo: DuneNode {
    private let engine = DuneEngine.shared
    private var contextBuffer = PixelBuffer(width: 320, height: 200)
    
    private var currentTime: TimeInterval = 0.0
    private var isPaletteReset = false

    private var circlePalette: ContiguousArray<UInt32> = []
    private var video: Video?

    init() {
        super.init("Logo")
    }

    
    override func onEnable() {
        video = engine.loadVideo("LOGO.HNM")
        initCirclePalette()
    }

    
    override func onDisable() {
        currentTime = 0.0
        video = nil
        circlePalette = []
        isPaletteReset = false
    }
    
    
    private func initCirclePalette() {
        // 284 frames
        circlePalette.append(contentsOf: interpolateColors(startColor: (0x00, 0x00, 0x00), endColor: (0x00, 0x00, 0x00), numSteps: 56))
        circlePalette.append(contentsOf: interpolateColors(startColor: (0x00, 0x00, 0x00), endColor: (0x9E, 0x23, 0x50), numSteps: 28))
        circlePalette.append(contentsOf: interpolateColors(startColor: (0x9E, 0x23, 0x50), endColor: (0x1D, 0x50, 0x95), numSteps: 28))
        circlePalette.append(contentsOf: interpolateColors(startColor: (0x1D, 0x50, 0x95), endColor: (0xD3, 0xE0, 0xAC), numSteps: 28))
        circlePalette.append(contentsOf: interpolateColors(startColor: (0xD3, 0xE0, 0xAC), endColor: (0x9E, 0x00, 0xAF), numSteps: 28))
        circlePalette.append(contentsOf: interpolateColors(startColor: (0x9E, 0x00, 0xAF), endColor: (0x00, 0x00, 0x00), numSteps: 28))
        circlePalette.append(contentsOf: interpolateColors(startColor: (0x00, 0x00, 0x00), endColor: (0x00, 0x00, 0x00), numSteps: 56))
    }
    

    private func interpolateColors(startColor: (UInt8, UInt8, UInt8), endColor: (UInt8, UInt8, UInt8), numSteps: Int) -> [UInt32] {
        var interpolatedColors: [UInt32] = []

        for step in 0..<numSteps {
            let ratio = Float(step) / Float(numSteps)

            let r = UInt32(Float(startColor.0) + ratio * Float(Int(endColor.0) - Int(startColor.0)))
            let g = UInt32(Float(startColor.1) + ratio * Float(Int(endColor.1) - Int(startColor.1)))
            let b = UInt32(Float(startColor.2) + ratio * Float(Int(endColor.2) - Int(startColor.2)))
            let a = UInt32(0xFF)
            
            let color: UInt32 = (a << 24) | (b << 16) | (g << 8) | r

            interpolatedColors.append(color)
        }

        return interpolatedColors
    }

    
    override func update(_ elapsedTime: TimeInterval) {
        guard let cryoVideo = video else {
            return
        }
        
        if currentTime == 0.0 {
            cryoVideo.setPalette()
        }
        
        let circlePaletteCount = circlePalette.count - 75
        
        currentTime += elapsedTime
        
        // Palette shift
        if currentTime < 5.0 {
            let palStart = Int((currentTime / 5.0) * CGFloat(circlePaletteCount))
            let palEnd = palStart + 75
            var chunk = Array<UInt32>(circlePalette[palStart..<palEnd])
            
            DuneEngine.shared.palette.update(&chunk, start: 85, count: 75)
        } else if !cryoVideo.hasFrames() {
            engine.sendEvent(self, .nodeEnded)
        }
    }
    
    
    override func render(_ buffer: PixelBuffer) {
        guard let cryoVideo = video else {
            return
        }
 
        if currentTime < 5.0 {
            cryoVideo.renderFrame(buffer)
            cryoVideo.renderFrame(buffer, flipX: true)
            cryoVideo.renderFrame(buffer, flipY: true)
            cryoVideo.renderFrame(buffer, flipX: true, flipY: true)
        } else if cryoVideo.hasFrames() {
            if !isPaletteReset {
                cryoVideo.setPalette()
                contextBuffer.clearBuffer()
                isPaletteReset = true
            }
            
            cryoVideo.setTime(currentTime - 5.0)

            if !cryoVideo.isFrameEmpty() {
                contextBuffer.copyPixels(to: buffer)
                cryoVideo.renderFrame(buffer)
                contextBuffer.copyPixels(from: buffer)
            } else {
                contextBuffer.copyPixels(to: buffer)
            }
        } else {
            contextBuffer.copyPixels(to: buffer)
        }
    }
}
