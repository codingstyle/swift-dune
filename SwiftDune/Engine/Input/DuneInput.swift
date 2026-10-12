//
//  DuneInput.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 11/10/2026.
//

enum DuneInputEventType {
  case unspecified
  case key
  case click
}


enum DuneInputMethodType {
  case mouse
  case keyboard
  case touch
}


protocol DuneInputMethod {
  var inputMethodType: DuneInputMethodType { get }
  var coordinates: DunePoint { get }

  @MainActor func update(_ input: Input)
}


protocol DuneInputEvent {
  var eventType: DuneInputEventType { get }
}

enum DuneSpecialKey: UInt16, CaseIterable {
  case keyReturn = 36
  case keyDelete = 51
  case keyEscape = 53
  case none = 0
}


struct DuneKeyEvent: DuneInputEvent {
  var eventType: DuneInputEventType = .key
  var specialKey: DuneSpecialKey = .none
  var char: String = ""
}


struct DuneClickEvent: DuneInputEvent {
  var eventType: DuneInputEventType = .click
  var point: DunePoint
}


@MainActor
final class Input {
    private var events = Queue<DuneInputEvent>()
    private var inputMethods: [DuneInputMethod] = []
  
    var mouseEnabled = true
    var coordinates = DunePoint.zero
  
    func registerInputMethod(_ method: DuneInputMethod) {
        inputMethods.append(method)
    }
  
  
    func enqueueEvent(_ event: DuneInputEvent) {
        events.enqueue(event)
    }
  
  
    func update(_ engine: DuneEngine) {
        var i = 0
      
        while i < inputMethods.count {
            inputMethods[i].update(self)
          
            if inputMethods[i].inputMethodType == .mouse {
                self.coordinates.x = inputMethods[i].coordinates.x
                self.coordinates.y = inputMethods[i].coordinates.y
            }
          
            i += 1
        }
      
        while let inputEvent = events.dequeueFirst() {
            engine.rootNode.onInput(inputEvent)
        }
    }
}
