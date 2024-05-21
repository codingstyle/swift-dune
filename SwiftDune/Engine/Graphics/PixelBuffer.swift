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
    
    var rawPointer: UnsafeMutablePointer<UInt32>
    private var clearRawPointer: UnsafeMutablePointer<UInt32>

    init(width: Int, height: Int) {
        self.width = width
        self.height = height
        self.frameSize = width * height
        self.frameSizeInBytes = frameSize * MemoryLayout<UInt32>.size
        self.rowSizeInBytes = width * MemoryLayout<UInt32>.size
        
        // Create buffer
        self.rawPointer = UnsafeMutablePointer<UInt32>.allocate(capacity: frameSize)
        
        self.clearRawPointer = UnsafeMutablePointer<UInt32>.allocate(capacity: frameSize)
        self.clearRawPointer.initialize(repeating: 0xFF000000, count: frameSize)
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
    
    
    func render(to buffer: PixelBuffer, effect: SpriteEffect, x: Int = 0, y: Int = 0) {
        switch effect {
        case .fadeIn(let start, let duration, let current):
            let progress = (current - start) / duration
            Effects.fade(sourceBuffer: self, destBuffer: buffer, progress: progress, offset: y * buffer.rowSizeInBytes)
            break
        case .fadeOut(let end, let duration, let current):
            let progress = (end - current) / duration
            Effects.fade(sourceBuffer: self, destBuffer: buffer, progress: progress, offset: y * buffer.rowSizeInBytes)
            break
        case .flipIn(let start, let duration, let current):
            let progress = (current - start) / duration
            Effects.flip(sourceBuffer: self, destBuffer: buffer, progress: progress, offset: y * buffer.rowSizeInBytes)
            break
        case .flipOut(let end, let duration, let current):
            let progress = (end - current) / duration
            Effects.flip(sourceBuffer: self, destBuffer: buffer, progress: progress, offset: y * buffer.rowSizeInBytes)
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
    
    func saveToPNG(as fileName: String, scale: Int = 1) {
        let bytesPerPixel = 4 // ABGR has 4 bytes per pixel
        let bitsPerComponent = 8
        let bytesPerRow = self.width * bytesPerPixel
        
        // Create a data provider from the components array
        guard let dataProvider = CGDataProvider(data: NSData(bytes: self.rawPointer, length: self.frameSizeInBytes)) else {
            print("Error creating data provider")
            return
        }
        
        // Create a CGImage from the data
        let bitmapInfo: CGBitmapInfo = [ CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue), .byteOrder32Big ]
        
        guard let cgImage = CGImage(width: self.width, height: self.height, bitsPerComponent: bitsPerComponent, bitsPerPixel: bytesPerPixel * bitsPerComponent, bytesPerRow: bytesPerRow, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: bitmapInfo, provider: dataProvider, decode: nil, shouldInterpolate: false, intent: .defaultIntent) else {
            print("Error creating CGImage")
            return
        }
        
        // Resize the image
        let scaledSize = CGSize(width: self.width * scale, height: self.height * scale)
        
        guard let resizedImage = cgImage.resize(to: scaledSize) else {
            print("Error resizing image")
            return
        }
        
        // Create a destination URL
        let downloadsDirectory = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        let fileURL = downloadsDirectory.appendingPathComponent(fileName)
        
        // Create a CGImageDestination
        guard let destination = CGImageDestinationCreateWithURL(fileURL as NSURL, kUTTypePNG, 1, nil) else {
            print("Error creating image destination")
            return
        }
        
        // Add the CGImage to the destination
        CGImageDestinationAddImage(destination, resizedImage, nil)
        
        // Finalize the destination to write the image to disk
        guard CGImageDestinationFinalize(destination) else {
            print("Error finalizing image destination")
            return
        }
        
        print("Image saved successfully")
    }
}
