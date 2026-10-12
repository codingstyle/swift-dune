//
//  Keyboard.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 10/05/2024.
//

import Foundation
import AppKit


final class Keyboard: DuneInputMethod {
    let inputMethodType: DuneInputMethodType = .keyboard
    let coordinates: DunePoint = DunePoint.zero
  
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
  
  
    @MainActor func update(_ input: Input) {
        while let keyPressed = keysPressed.dequeueFirst() {
            input.enqueueEvent(keyPressed)
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
}
