//
//  Renderer.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 29/06/2024.
//

import Foundation
import SwiftUI
import Metal
import MetalKit


final class Renderer: NSObject, ObservableObject, MTKViewDelegate {
    private let region = MTLRegionMake2D(0, 0, 320, 200)
    private let frameSize = 320 * 200 * 4
    
    private var device: MTLDevice
    private var commandQueue: MTLCommandQueue
    private var texture: MTLTexture
    private var vertexBuffer: MTLBuffer
    private var pipelineState: MTLRenderPipelineState
    private var rawBufferPointer: UnsafeMutablePointer<UInt8>
    private var shouldTakeScreenshot = false
    private var screenshotScale = 3

    var metalView: MTKView

    @Published var tick: UInt64 = 0
    
    override init() {
        device = MTLCreateSystemDefaultDevice()!
        commandQueue = device.makeCommandQueue()!
        
        // Create Texture
        let textureDescriptor = MTLTextureDescriptor()
        textureDescriptor.pixelFormat = .rgba8Unorm
        textureDescriptor.width = region.size.width
        textureDescriptor.height = region.size.height
        textureDescriptor.usage = .shaderRead
        
        texture = device.makeTexture(descriptor: textureDescriptor)!

        metalView = MTKView(frame: CGRectMake(0, 0, 320, 200), device: device)
        metalView.framebufferOnly = false
        metalView.colorPixelFormat = .rgba8Unorm
        
        // Load the shader files
        let defaultLibrary = device.makeDefaultLibrary()!
        let vertexFunction = defaultLibrary.makeFunction(name: "vertex_main")
        let fragmentFunction = defaultLibrary.makeFunction(name: "fragment_main")
        
        // Create the vertex descriptor
        let vertexDescriptor = MTLVertexDescriptor()
        vertexDescriptor.attributes[0].format = .float4
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0
        vertexDescriptor.attributes[1].format = .float2
        vertexDescriptor.attributes[1].offset = 16
        vertexDescriptor.attributes[1].bufferIndex = 0
        vertexDescriptor.layouts[0].stride = 24
        vertexDescriptor.layouts[0].stepRate = 1
        vertexDescriptor.layouts[0].stepFunction = .perVertex
        
        // Create the pipeline state tying everything together
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.vertexDescriptor = vertexDescriptor
        pipelineDescriptor.colorAttachments[0].pixelFormat = metalView.colorPixelFormat
        
        pipelineState = try! device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        
        // Create the vertex data for a simple rectangle made of 2 polygons
        let vertexData: [Float] = [
            -1.0, -1.0, 0.0, 1.0,  0.0, 1.0,
             1.0, -1.0, 0.0, 1.0,  1.0, 1.0,
            -1.0,  1.0, 0.0, 1.0,  0.0, 0.0,
             1.0,  1.0, 0.0, 1.0,  1.0, 0.0,
        ]
        
        vertexBuffer = device.makeBuffer(bytes: vertexData, length: vertexData.count * MemoryLayout<Float>.size, options: [])!
        
        // Create a frame buffer that will contain RGBA components for each pixel to update the texture
        rawBufferPointer = UnsafeMutablePointer<UInt8>.allocate(capacity: frameSize)
        
        super.init()

        metalView.delegate = self
    }
    
    deinit {
        rawBufferPointer.deallocate()
    }
    
    
    func update(_ buffer: PixelBuffer) {
        let engine = DuneEngine.shared
        
        // Clear the pixel buffer
        memset(rawBufferPointer, 0, frameSize)
        
        // Convert the buffer containing palette indexes to an actual pixel buffer with RGBA colors
        var n = 0
        
        while n < buffer.frameSizeInBytes {
            let destIndex = n * 4
            let paletteIndex = buffer.rawPointer[n]
            
            if paletteIndex == 0 {
                n += 1
                continue
            }
            
            var color = engine.palette.rawPointer[Int(paletteIndex)]
            memcpy(rawBufferPointer + destIndex, &color, 4)
            n += 1
        }
        
        // Screenshots are taken one rendering to framebuffer is done
        if shouldTakeScreenshot {
            captureToPNG(screenshotScale)
            shouldTakeScreenshot = false
        }
        
        // Fill the texture with RGBA pixel buffer data
        texture.replace(region: region, mipmapLevel: 0, withBytes: rawBufferPointer, bytesPerRow: 320 * 4)
    }
    
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // Unused
    }
    
    func draw(in view: MTKView) {
        let renderer = DuneEngine.shared.renderer
        
        guard let drawable = renderer.metalView.currentDrawable else {
            return
        }

        guard let commandBuffer = renderer.commandQueue.makeCommandBuffer() else {
            return
        }
        
        let passDescriptor = renderer.metalView.currentRenderPassDescriptor
        
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: passDescriptor!) else {
            return
        }
        
        encoder.setRenderPipelineState(renderer.pipelineState)
        encoder.setVertexBuffer(renderer.vertexBuffer, offset: 0, index: 0)
        encoder.setFragmentTexture(renderer.texture, index: 0)
        
        // Draw the texture to the screen
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
                
        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
        
        tick += 1
    }
    
    
    func requestScreenshot(_ scale: Int = 1) {
        self.screenshotScale = scale
        self.shouldTakeScreenshot = true
    }
    
    
    private func captureToPNG(_ scale: Int) {
        let bytesPerPixel = 4 // ABGR has 4 bytes per pixel
        let bitsPerComponent = 8
        let bytesPerRow = self.region.size.width * bytesPerPixel
        
        // Create a data provider from the components array
        guard let dataProvider = CGDataProvider(data: NSData(bytes: self.rawBufferPointer, length: self.frameSize)) else {
            DuneEngine.shared.logger.log(.error, "Error creating data provider")
            return
        }
        
        // Create a CGImage from the data
        let bitmapInfo: CGBitmapInfo = [ CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue), .byteOrder32Big ]
        
        guard let cgImage = CGImage(width: self.region.size.width, height: self.region.size.height, bitsPerComponent: bitsPerComponent, bitsPerPixel: bytesPerPixel * bitsPerComponent, bytesPerRow: bytesPerRow, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: bitmapInfo, provider: dataProvider, decode: nil, shouldInterpolate: false, intent: .defaultIntent) else {
            DuneEngine.shared.logger.log(.error, "Error creating CGImage")
            return
        }
        
        // Resize the image
        let scaledSize = CGSize(width: self.region.size.width * scale, height: self.region.size.height * scale)
        
        guard let resizedImage = cgImage.resize(to: scaledSize) else {
            DuneEngine.shared.logger.log(.error, "Error resizing image")
            return
        }
        
        // Create a destination URL
        let date = NSDate()
        let fileName = "DuneCapture_\(date.timeIntervalSince1970)@\(scale)x.png"
        let downloadsDirectory = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        let fileURL = downloadsDirectory.appendingPathComponent(fileName)
        
        // Create a CGImageDestination
        guard let destination = CGImageDestinationCreateWithURL(fileURL as NSURL, kUTTypePNG, 1, nil) else {
            DuneEngine.shared.logger.log(.error, "Error creating image destination")
            return
        }
        
        // Add the CGImage to the destination
        CGImageDestinationAddImage(destination, resizedImage, nil)
        
        // Finalize the destination to write the image to disk
        guard CGImageDestinationFinalize(destination) else {
            DuneEngine.shared.logger.log(.error, "Error finalizing image destination")
            return
        }
        
        DuneEngine.shared.logger.log(.info, "Image saved successfully")
    }
}



struct MetalRenderView: NSViewRepresentable {
    typealias NSViewType = MTKView

    static let tagID = 0x4d75616427446962
    
    private let engine = DuneEngine.shared

    @ObservedObject var renderer: Renderer
    
    init() {
        self.renderer = engine.renderer
    }
    
    func makeNSView(context: Context) -> MTKView {
        return engine.renderer.metalView
    }
    
    func updateNSView(_ nsView: MTKView, context: Context) {
        nsView.setNeedsDisplay(nsView.bounds)
    }
}
