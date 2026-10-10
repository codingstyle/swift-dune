//
//  Mouse.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 12/06/2024.
//

import Foundation
import AppKit


struct DuneMouseClickEvent {
    var point: DunePoint
}

final class Mouse {
    private var monitorID: Any?
    private var activityObservers: [NSObjectProtocol] = []
    private var trackingView: NSView?
    private var nativeCursorHidden = false

    var coordinates: DunePoint = .zero
    var cursorVisible = false

    var mouseClicks = Queue<DuneMouseClickEvent>()

    init() {
        self.monitorID = NSEvent.addLocalMonitorForEvents(matching: [.mouseEntered, .mouseExited, .mouseMoved, .leftMouseDragged, .leftMouseUp]) { event in
            if self.processMouseEvent(event) {
                return nil
            }
            
            return event
        }

        let center = NotificationCenter.default
        activityObservers.append(center.addObserver(forName: NSApplication.didResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
            self?.setNativeCursorHidden(false)
        })
        activityObservers.append(center.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            self?.syncNativeCursor()
        })
    }
    
    
    deinit {
        setNativeCursorHidden(false)

        if let monitorID = self.monitorID {
            NSEvent.removeMonitor(monitorID)
        }

        let center = NotificationCenter.default
        var index = 0

        while index < activityObservers.count {
            center.removeObserver(activityObservers[index])
            index += 1
        }
    }


    /// Hides the system pointer while it is over `view`. Movement and clicks still update `coordinates`.
    func track(_ view: NSView) {
        if trackingView === view {
            return
        }

        view.addTrackingArea(NSTrackingArea(
            rect: view.bounds,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeInKeyWindow, .inVisibleRect],
            owner: view,
            userInfo: nil
        ))
        trackingView = view
        syncNativeCursor()
    }


    private func syncNativeCursor() {
        guard let view = trackingView, let window = view.window, window.isKeyWindow else {
            setNativeCursorHidden(false)
            return
        }

        let location = view.convert(window.convertPoint(fromScreen: NSEvent.mouseLocation), from: nil)
        setNativeCursorHidden(view.bounds.contains(location))
    }


    private func setNativeCursorHidden(_ hidden: Bool) {
        if hidden == nativeCursorHidden {
            return
        }

        if hidden {
            NSCursor.hide()
        } else {
            NSCursor.unhide()
        }

        nativeCursorHidden = hidden
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
            setNativeCursorHidden(false)
            return false
        }

        guard let renderView = findRenderView(contentView) else {
            coordinates.reset()
            setNativeCursorHidden(false)
            return false
        }
        
        let renderFrame = renderView.superview!.frame
        let eventLocation = NSPoint(x: event.locationInWindow.x, y: contentView.bounds.size.height - event.locationInWindow.y)
        let insideGameView = event.type != .mouseExited && renderFrame.contains(eventLocation)

        if !insideGameView {
            coordinates.reset()
            setNativeCursorHidden(false)
            return false
        }

        setNativeCursorHidden(trackingView != nil && event.window?.isKeyWindow == true)
        
        coordinates.x = Int16(eventLocation.x - renderFrame.minX) / 2
        coordinates.y = Int16(eventLocation.y - renderFrame.minY) / 2
        
        if event.type == .leftMouseUp {
            mouseClicks.enqueue(DuneMouseClickEvent(point: coordinates))
        }
        
        return true
    }
}
