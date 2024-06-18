//
//  RenderView.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 10/10/2023.
//

import Foundation
import SwiftUI

struct RenderView: NSViewRepresentable {
    typealias NSViewType = NSImageView

    var engine: Binding<DuneEngine>

    private let renderBounds = NSRect(x: 0, y: 0, width: 640, height: 400)
    private var renderLayer: RenderLayer
    private var imageView: NSImageView
    
    static let tagID = 0x4d75616427446962  // Muad'Dib in hexa
    
    private var bitmapRep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: 320,
        pixelsHigh: 200,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .calibratedRGB,
        bytesPerRow: 320 * 4,
        bitsPerPixel: 32
    )!
    
    init(engine: Binding<DuneEngine>, renderLayer: RenderLayer = RenderLayer(), imageView: NSImageView = NSImageView()) {
        self.engine = engine
        self.renderLayer = renderLayer
        self.imageView = imageView
    }
    
    
    func makeNSView(context: Context) -> NSImageView {
        imageView.tag = RenderView.tagID
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.wantsLayer = true
        imageView.layer?.backgroundColor = NSColor.black.cgColor
        imageView.sizeToFit()

        renderLayer.anchorPoint = .zero
        renderLayer.bounds = renderBounds
        renderLayer.magnificationFilter = .nearest
        renderLayer.minificationFilter = .nearest
        renderLayer.allowsEdgeAntialiasing = false
        renderLayer.shouldRasterize = false
        renderLayer.contentsScale = NSScreen.main!.backingScaleFactor
        
        engine.wrappedValue.onRender = self.onRender

        return imageView
    }
    
    
    func updateNSView(_ nsView: NSImageView, context: Context) {
        nsView.layer?.addSublayer(renderLayer)
        renderLayer.setNeedsDisplay()
    }
    
    
    func onRender(_ buffer: PixelBuffer) {
        guard let imageBuffer = bitmapRep.bitmapData else {
            print("engineDidRender() - unable to retrieve bitmapData")
            return
        }
        
        _ = memcpy(imageBuffer, buffer.rawPointer, 320 * 200 * 4)

        renderLayer.currentBitmapRep = bitmapRep
        renderLayer.setNeedsDisplay()
    }
}


class RenderLayer: CALayer {
    var pixelBuffer: PixelBuffer?
    var currentBitmapRep: NSBitmapImageRep?
    let frameSizeInBytes = 320 * 200 * 4
    
    override func draw(in context: CGContext) {
        guard let buffer = currentBitmapRep else {
            print("RenderLayer: No buffer")
            return
        }
        
        context.interpolationQuality = .none
        context.draw(buffer.cgImage!, in: self.bounds)
    }
}
