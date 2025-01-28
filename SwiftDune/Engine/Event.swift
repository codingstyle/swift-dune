//
//  DuneEvent.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 22/12/2024.
//

// @see https://blog.bitbebop.com/game-event-system-swift/

/*
enum DuneEvent {
    case nodeEnded
    case uiMenuChanged(items: [UInt16])
    case uiLeftPanelChanged(flag: Int)
    case uiRightPanelChanged(flag: Int)
}

protocol DuneEventObserver: AnyObject {
    func onEvent(_ source: String, _ e: DuneEvent)
}*/


public class DuneEvent<T> {
  public typealias EventAction = (_ subject: T) -> Void
  
  /// Listener wrapper to be able to use a weak reference to the listener.
  private struct Listener {
    /// Weak reference to the listener.
    weak var listener: AnyObject?
    
    /// Action closure provided by the listener.
    var action: EventAction
  }
  
  private var listeners: [ObjectIdentifier: Listener] = [:]
  
  
  /// Register a new listener for the event.
  public func addListener(_ listener: AnyObject, action: @escaping EventAction) {
    let id = ObjectIdentifier(listener)
    
    listeners[id] = Listener(listener: listener, action: action)
  }
  
  
  /// Unregister a listener for the event.
  public func removeListener(_ listener: AnyObject) {
    let id = ObjectIdentifier(listener)
    
    listeners.removeValue(forKey: id)
  }
  
  
  /// Raise the event to notify all registered listeners.
  public func notify(_ subject: T) {
    for (id, listener) in listeners {
      // If the listening object is no longer in memory, we can clean up the listener for its ID.
      if listener.listener == nil {
        listeners.removeValue(forKey: id)
        continue
      }
      
      listener.action(subject)
    }
  }
}



public class EventManager {
    //static let shared = EventManager()
   
    private init() {}
    
    /// Event channels
    static let nodeEndedEvent = DuneEvent<NodeEventData>()
}
