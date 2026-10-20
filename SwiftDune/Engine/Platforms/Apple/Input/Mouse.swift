//
//  Mouse.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 12/06/2024.
//

import Foundation
import AppKit

final class Mouse: DuneInputMethod {
    let inputMethodType: DuneInputMethodType = .mouse
    var coordinates: DunePoint = .zero

    private var monitorID: Any?
    private var activityObservers: [NSObjectProtocol] = []
    private weak var trackingView: NSView?
    private var nativeCursorHidden = false
    private var mouseClicks = Queue<DuneClickEvent>()

    private static let gameWidth: CGFloat = 320
    private static let gameHeight: CGFloat = 200

    var cursorVisible = false

    init() {
        self.monitorID = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseUp]) { event in
            self.processClick(event)
            return event
        }

        let center = NotificationCenter.default

        activityObservers.append(center.addObserver(forName: NSApplication.didResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
            self?.syncPointer()
        })

        activityObservers.append(center.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            self?.syncPointer()
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


    @MainActor func update(_ input: Input) {
        syncPointer()

        while let click = mouseClicks.dequeueFirst() {
            input.enqueueEvent(click)
        }
    }


    /// Hides the system pointer while it is over `view`. Movement and clicks still update `coordinates`.
    @MainActor func track(_ view: NSView) {
        trackingView = view
        syncPointer()
    }


    /// Samples the pointer in `trackingView` each frame.
    ///
    /// A tracking area stops delivering `mouseMoved` once the system cursor is hidden, and it never
    /// starts if the pointer is already inside the view. The view is also resizable, so the 320×200
    /// frame has to be mapped from the view's current bounds.
    @MainActor private func syncPointer() {
        cursorVisible = false

        guard let view = trackingView, let window = view.window, NSApp.isActive else {
            coordinates.reset()
            setNativeCursorHidden(false)
            return
        }

        let mouseLocation = NSEvent.mouseLocation

        guard NSWindow.windowNumber(at: mouseLocation, belowWindowWithWindowNumber: 0) == window.windowNumber else {
            coordinates.reset()
            setNativeCursorHidden(false)
            return
        }

        let location = view.convert(window.convertPoint(fromScreen: mouseLocation), from: nil)
        let bounds = view.bounds

        guard bounds.width > 0, bounds.height > 0, bounds.contains(location) else {
            coordinates.reset()
            setNativeCursorHidden(false)
            return
        }

        cursorVisible = true
        setNativeCursorHidden(true)
        coordinates = gamePoint(location, in: bounds)
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


    @MainActor private func processClick(_ event: NSEvent) {
        guard let view = trackingView, event.window === view.window else {
            return
        }

        let bounds = view.bounds
        let location = view.convert(event.locationInWindow, from: nil)

        guard bounds.width > 0, bounds.height > 0, bounds.contains(location) else {
            return
        }

        mouseClicks.enqueue(DuneClickEvent(point: gamePoint(location, in: bounds)))
    }


    private func gamePoint(_ location: NSPoint, in bounds: NSRect) -> DunePoint {
        let x = Int16((location.x - bounds.minX) / bounds.width * Mouse.gameWidth)
        let y = Int16((bounds.maxY - location.y) / bounds.height * Mouse.gameHeight)
        return DunePoint(min(max(x, 0), 319), min(max(y, 0), 199))
    }
}
