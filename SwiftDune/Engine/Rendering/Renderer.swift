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
    let region = MTLRegionMake2D(0, 0, 320, 200)

    var metalView: MTKView
    var device: MTLDevice
    var commandQueue: MTLCommandQueue
    var texture: MTLTexture
    var vertexBuffer: MTLBuffer
    var pipelineState: MTLRenderPipelineState
    
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
        
        // Create the pipeline state
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.vertexDescriptor = vertexDescriptor
        pipelineDescriptor.colorAttachments[0].pixelFormat = metalView.colorPixelFormat
        
        pipelineState = try! device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        
        // Create vertex data
        let vertexData: [Float] = [
            -1.0, -1.0, 0.0, 1.0,  0.0, 1.0,
             1.0, -1.0, 0.0, 1.0,  1.0, 1.0,
            -1.0,  1.0, 0.0, 1.0,  0.0, 0.0,
             1.0,  1.0, 0.0, 1.0,  1.0, 0.0,
        ]
        
        vertexBuffer = device.makeBuffer(bytes: vertexData, length: vertexData.count * MemoryLayout<Float>.size, options: [])!

        super.init()

        metalView.delegate = self
    }
    
    
    func update(_ buffer: PixelBuffer) {
        // Fill the texture with pixel buffer data
        texture.replace(region: region, mipmapLevel: 0, withBytes: buffer.rawPointer, bytesPerRow: 320 * 4)
    }
    
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        //
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
