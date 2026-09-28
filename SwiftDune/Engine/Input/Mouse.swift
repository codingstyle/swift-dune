//
//  Mouse.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 12/06/2024.
//

import Foundation
import CoreGraphics
#if os(macOS)
import AppKit
#endif


struct DuneMouseClickEvent {
    var point: DunePoint
}

final class Mouse {
    private var monitorID: Any?
    var coordinates: DunePoint = .zero
    var cursorVisible = false

    var mouseClicks = Queue<DuneMouseClickEvent>()

    #if os(macOS)
    init() {
        self.monitorID = NSEvent.addLocalMonitorForEvents(matching: [.mouseEntered, .mouseExited, .mouseMoved, .leftMouseUp]) { event in
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
            if view.className == "MTKView" {
                return view
            }
            
            if let childView = findRenderView(view) {
                return childView
            }
        }
        
        return nil
    }
    
    
    private func processMouseEvent(_ event: NSEvent) -> Bool {
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

        if !renderFrame.contains(eventLocation) {
            coordinates.reset()
            return false
        }
        
        coordinates.x = Int16(eventLocation.x - renderFrame.minX) / 2
        coordinates.y = Int16(eventLocation.y - renderFrame.minY) / 2
        
        if event.type == .leftMouseUp {
            mouseClicks.enqueue(DuneMouseClickEvent(point: coordinates))
        }
        
        return true
    }
    #endif


    /// Maps a touch/pointer location inside the game view (whose bounds show
    /// the whole 320x200 frame) to game coordinates. Used by the iOS front end.
    func updateTouch(_ location: CGPoint, in bounds: CGRect, ended: Bool) {
        guard bounds.width > 0, bounds.height > 0 else { return }

        let x = (location.x - bounds.minX) * 320.0 / bounds.width
        let y = (location.y - bounds.minY) * 200.0 / bounds.height

        coordinates.x = Int16(max(0, min(319, x)))
        coordinates.y = Int16(max(0, min(199, y)))

        if ended {
            mouseClicks.enqueue(DuneMouseClickEvent(point: coordinates))
        }
    }
}
