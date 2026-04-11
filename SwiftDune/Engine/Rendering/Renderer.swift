//
//  Renderer.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 29/06/2024.
//

import Foundation
import Metal
import MetalKit
import UniformTypeIdentifiers


final class Renderer: NSObject, ObservableObject, MTKViewDelegate {
    private let region = MTLRegionMake2D(0, 0, 320, 200)
    private let frameSize = 320 * 200 * 4
  
    private let vertexData: [Float] = [
        -1.0, -1.0, 0.0, 1.0, 0.0, 1.0,
         1.0, -1.0, 0.0, 1.0, 1.0, 1.0,
        -1.0,  1.0, 0.0, 1.0, 0.0, 0.0,
         1.0,  1.0, 0.0, 1.0, 1.0, 0.0,
    ]
    private let vertexDataSize = 24 * MemoryLayout<Float>.size
    
    private var device: MTLDevice
    private var commandQueue: MTLCommandQueue
    private var texture: MTLTexture
    private var pipelineState: MTLRenderPipelineState
    private var rawBufferPointer: UnsafeMutablePointer<UInt8>
    private var shouldTakeScreenshot = false
    private var screenshotScale = 3

    var metalView: MTKView
    
    override init() {
        device = MTLCreateSystemDefaultDevice()!
        commandQueue = device.makeCommandQueue(maxCommandBufferCount: 1)!
        
        // Create Texture
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: region.size.width, height: region.size.height, mipmapped: false)
        textureDescriptor.sampleCount = 1
        textureDescriptor.usage = [.shaderRead, .renderTarget]
        textureDescriptor.storageMode = .shared
      
        texture = device.makeTexture(descriptor: textureDescriptor)!
        
        metalView = MTKView(frame: .zero, device: device)
        metalView.colorPixelFormat = .rgba8Unorm
        metalView.framebufferOnly = false
        metalView.preferredFramesPerSecond = 60
        //metalView.presentsWithTransaction = true  // Reduces memory overhead
        //metalView.enableSetNeedsDisplay = true  // Only render when needed
        metalView.autoResizeDrawable = true
        metalView.depthStencilPixelFormat = .invalid
        metalView.depthStencilAttachmentTextureUsage = .unknown
        metalView.sampleCount = 1
        metalView.clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1.0)
        metalView.releaseDrawables()
      
        // Load the shader files
        let defaultLibrary = device.makeDefaultLibrary()!
        let vertexFunction = defaultLibrary.makeFunction(name: "vertex_main")
        let fragmentFunction = defaultLibrary.makeFunction(name: "fragment_main")
        
        // Create the vertex descriptor
        let vertexDescriptor = MTLVertexDescriptor()
        vertexDescriptor.attributes[0].format = .float3
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0
        vertexDescriptor.attributes[1].format = .float3
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
        pipelineDescriptor.depthAttachmentPixelFormat = .invalid
        pipelineDescriptor.stencilAttachmentPixelFormat = .invalid
        
        pipelineState = try! device.makeRenderPipelineState(descriptor: pipelineDescriptor)
      
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
        
        let srcBuffer = buffer.rawPointer
        let rawPalettePointer = engine.palette.rawPointer
      
        while n < buffer.frameSizeInBytes {
            
            if srcBuffer[n] != 0 {
                memcpy(rawBufferPointer + (n * 4), rawPalettePointer + Int(srcBuffer[n]), 4)
            }
            
            n += 1
        }
        
        
        // Screenshots are taken one rendering to framebuffer is done
        if shouldTakeScreenshot {
            captureToPNG(screenshotScale)
            shouldTakeScreenshot = false
        }
    }
    
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // Unused
    }
    
    func draw(in view: MTKView) {
        autoreleasepool {
            // Fill the texture with RGBA pixel buffer data
            texture.replace(region: region, mipmapLevel: 0, withBytes: rawBufferPointer, bytesPerRow: 320 * 4)
          
            guard let commandBuffer = commandQueue.makeCommandBuffer(),
                  let passDescriptor = metalView.currentRenderPassDescriptor,
                  let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: passDescriptor) else {
              return
            }
            
            encoder.setRenderPipelineState(pipelineState)
            encoder.setVertexBytes(vertexData, length: vertexDataSize, index: 0)
            encoder.setFragmentTexture(texture, index: 0)
            
            // Draw the texture to the screen
            encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            encoder.endEncoding()
            
            guard let drawable = view.currentDrawable else {
                return
            }
            
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
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
        guard let destination = CGImageDestinationCreateWithURL(fileURL as NSURL, UTType.png.identifier as CFString, 1, nil) else {
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

/*
struct MetalRenderView: NSViewRepresentable {
    typealias NSViewType = MTKView

    static let tagID = 0x4d75616427446962
    private let engine = DuneEngine.shared

    func makeNSView(context: Context) -> MTKView {
        return engine.renderer.metalView
    }
    
    func updateNSView(_ nsView: MTKView, context: Context) {
        nsView.setNeedsDisplay(nsView.bounds)
    }
}
*/


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
