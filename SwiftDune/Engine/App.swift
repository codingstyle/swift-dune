//
//  App.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 11/10/2026.
//

enum AppState {
    case closed
}

struct AppStateEventData {
    var state: AppState
    var message: String?
  
    init(_ state: AppState, _ message: String?) {
        self.state = state
        self.message = message
    }
}

extension EventManager {
    static let appStateChangedEvent = DuneEvent<AppStateEventData>()
}
