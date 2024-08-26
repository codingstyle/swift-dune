//
//  PixelBuffer.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 03/12/2023.
//

import Foundation
import CoreGraphics
import UniformTypeIdentifiers
import ImageIO

final class PixelBuffer {
    var tag: UInt32 = 0x0000

    let width: Int
    let height: Int
    let frameSize: Int
    let frameSizeInBytes: Int
    let rowSizeInBytes: Int
    
    var rawPointer: UnsafeMutablePointer<UInt8>
    private var clearRawPointer: UnsafeMutablePointer<UInt8>

    init(width: Int, height: Int) {
        self.width = width
        self.height = height
        self.frameSize = width * height
        self.frameSizeInBytes = frameSize * MemoryLayout<UInt8>.size
        self.rowSizeInBytes = width * MemoryLayout<UInt8>.size
        
        // Create buffer
        self.rawPointer = UnsafeMutablePointer<UInt8>.allocate(capacity: frameSize)
        
        self.clearRawPointer = UnsafeMutablePointer<UInt8>.allocate(capacity: frameSize)
        self.clearRawPointer.initialize(repeating: 0x00, count: frameSize)
    }
    
    deinit {
        self.rawPointer.deallocate()
        self.clearRawPointer.deallocate()
    }

    
    func clearBuffer(transparent: Bool = false) {
        if transparent {
            _ = memset(rawPointer, 0, frameSizeInBytes)
        } else {
            _ = memcpy(rawPointer, clearRawPointer, frameSizeInBytes)
        }
    }
    
    
    func render(to buffer: PixelBuffer, effect: SpriteEffect = .none, x: Int = 0, y: Int = 0) {
        switch effect {
        case .fadeIn(let start, let duration, let current):
            let progress = (current - start) / duration
            Effects.fade(progress: progress)
            let size = max(0, (buffer.height - y) * buffer.rowSizeInBytes)
            self.copyPixels(to: buffer, offset: y * buffer.width, size: size)
            break
        case .fadeOut(let end, let duration, let current):
            let progress = (end - current) / duration
            Effects.fade(progress: progress)
            let size = max(0, (buffer.height - y) * buffer.rowSizeInBytes)
            self.copyPixels(to: buffer, offset: y * buffer.width, size: size)
            break
        case .flipIn(let start, let duration, let current):
            let progress = (current - start) / duration
            Effects.flip(sourceBuffer: self, destBuffer: buffer, progress: progress, offset: y * buffer.rowSizeInBytes)
            break
        case .flipOut(let end, let duration, let current):
            let progress = (end - current) / duration
            Effects.flip(sourceBuffer: self, destBuffer: buffer, progress: progress, offset: y * buffer.rowSizeInBytes)
            break
        case .dissolveIn(let start, let duration, let current):
            let progress = 1.0 - ((current - start) / duration)
            let size = max(0, (buffer.height - y) * buffer.rowSizeInBytes)
            self.copyPixels(to: buffer, offset: y * buffer.width, size: size)
            Effects.dissolve(destBuffer: buffer, progress: progress, yOffset: y)
            break
        case .dissolveOut(let end, let duration, let current):
            let progress = 1.0 - ((end - current) / duration)
            let size = max(0, (buffer.height - y) * buffer.rowSizeInBytes)
            self.copyPixels(to: buffer, offset: y * buffer.width, size: size)
            Effects.dissolve(destBuffer: buffer, progress: progress, yOffset: y)
            break
        case .pixelate(let end, let duration, let current):
            let progress = (end - current) / duration
            Effects.pixelate(sourceBuffer: self, destBuffer: buffer, progress: progress, offset: y * buffer.rowSizeInBytes)
            break
        case .zoom(let start, let duration, let current, let from, let to):
            let progress = Math.clampf((current - start) / duration, 0.0, 1.0)
            let rect = Math.lerpRect(from, to, progress)
            Effects.zoom(sourceBuffer: self, destBuffer: buffer, sourceRect: rect)
        default:
            let size = max(0, (buffer.height - y) * buffer.rowSizeInBytes)
            self.copyPixels(to: buffer, offset: y * buffer.width, size: size)
        }
    }
    
    
    func copyPixels(from sourceBuffer: PixelBuffer) {
        _ = memcpy(rawPointer, sourceBuffer.rawPointer, frameSizeInBytes)
    }
    
    
    func copyPixels(to destBuffer: PixelBuffer, offset: Int = 0, size: Int = -1) {
        _ = memcpy(destBuffer.rawPointer + offset, rawPointer, size == -1 ? frameSizeInBytes : size)
    }
}
