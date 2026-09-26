//
//  Keyboard.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 10/05/2024.
//

import Foundation
#if os(macOS)
import AppKit
#endif

enum DuneSpecialKey: UInt16, CaseIterable {
    case keyReturn = 36
    case keyDelete = 51
    case keyEscape = 53
    case keyLeft = 123
    case keyRight = 124
    case keyDown = 125
    case keyUp = 126
    case none = 0
}


struct DuneKeyEvent {
    var specialKey: DuneSpecialKey = .none
    var char: String = ""
}


final class Keyboard {
    private var monitorID: Any?
    var keysPressed = Queue<DuneKeyEvent>()
    
    #if os(macOS)
    init() {
        self.monitorID = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if self.processKeyUpEvent(event) {
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
    
    
    private func processKeyUpEvent(_ event: NSEvent) -> Bool {
        var processed = false
        
        var keyEvent = DuneKeyEvent()
        
        for key in DuneSpecialKey.allCases {
            if event.keyCode == key.rawValue {
                keyEvent.specialKey = key
                processed = true
            }
        }

        if let chars = event.characters {
            if !chars.isEmpty {
                keyEvent.char = String(chars[0])
                processed = true
            }
        }
        
        if processed {
            keysPressed.enqueue(keyEvent)
        }

        return processed
    }
    #endif


    /// Queues a key press coming from a non-AppKit source (iOS on-screen
    /// controls or a hardware keyboard attached to an iPhone/iPad).
    func push(_ keyEvent: DuneKeyEvent) {
        keysPressed.enqueue(keyEvent)
    }
}
