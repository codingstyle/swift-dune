//
//  SwiftDuneApp.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 21/08/2023.
//

import SwiftUI

enum DuneViewMode {
    case game
    case editor
}

struct DuneMenus: Commands {
    @Environment(\.openWindow) private var openWindow
    @Binding var viewMode: DuneViewMode
    
    var body: some Commands {
        CommandGroup(replacing: .singleWindowList, addition: {
            Button("Game View") {
                viewMode = .game
            }
            .keyboardShortcut("G", modifiers: .command)

            Button("Editor View") {
                viewMode = .editor
            }
            .keyboardShortcut("E", modifiers: .command)

            Button("Show stats") {
                openWindow(id: "StatsWindow")
            }
            .keyboardShortcut("S", modifiers: .option)
        })
    }
}

@main
struct SwiftDuneApp: App {
    @State var viewMode: DuneViewMode = .editor
    
    var body: some Scene {
        WindowGroup {
            if viewMode == .editor {
                EditorView()
            } else if viewMode == .game {
                GameView()
            }
        }
        .commands {
            DuneMenus(viewMode: $viewMode)
        }
        
        WindowGroup(id: "StatsWindow") {
            StatsView()
        }
        .windowResizability(.contentMinSize)
        .defaultPosition(.trailing)
    }
}
