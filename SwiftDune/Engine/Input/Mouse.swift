//
//  Mouse.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 12/06/2024.
//

import Foundation
import AppKit

final class Mouse {
    private var monitorID: Any?
    var coordinates: DunePoint = .zero
    var cursorVisible = false
    
    init() {
        self.monitorID = NSEvent.addLocalMonitorForEvents(matching: [.mouseEntered, .mouseExited, .mouseMoved]) { event in
            if self.processMouseEvent(event) {
                return nil
            }
            
            return event
        }
    }
    
    
    deinit {
        if let monitorID = self.monitorID {
            NSEvent.removeMonitor(monitorID)
        }
    }
    
    
    private func findRenderView(_ parentView: NSView) -> NSView? {
        for view in parentView.subviews {
            if view.tag == RenderView.tagID {
                return view
            }
            
            if let childView = findRenderView(view) {
                return childView
            }
        }
        
        return nil
    }
    
    
    private func processMouseEvent(_ event: NSEvent) -> Bool {
        var processed = false

        guard let contentView = event.window?.contentView else {
            coordinates.reset()
            return false
        }

        guard let renderView = findRenderView(contentView) else {
            coordinates.reset()
            return false
        }
        
        let renderFrame = renderView.superview!.frame
        let eventLocation = NSPoint(x: event.locationInWindow.x, y: contentView.bounds.size.height - event.locationInWindow.y)

        if renderFrame.contains(eventLocation) {
            coordinates.x = Int16(eventLocation.x - renderFrame.minX) / 2
            coordinates.y = Int16(eventLocation.y - renderFrame.minY) / 2
            processed = true
        } else {
            coordinates.reset()
        }
        
        return processed
    }
}
