//
//  Keyboard.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 10/05/2024.
//

import Foundation
import AppKit

enum DuneKeyEvent: UInt16, CaseIterable {
    case keyReturn = 36
    case keyEscape = 53
}


final class Keyboard {
    private var monitorID: Any?
    var keysPressed = Queue<DuneKeyEvent>()
    
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
        
        for key in DuneKeyEvent.allCases {
            if event.keyCode == key.rawValue {
                keysPressed.enqueue(key)
                processed = true
            }
        }
        
        return processed
    }
}
