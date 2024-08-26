//
//  SwiftDuneApp.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 21/08/2023.
//

import SwiftUI

struct DuneWindowAccessor: NSViewRepresentable {
    @Binding var window: NSWindow?

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            self.window = view.window
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}


@main
struct DuneGameApp: App {
    @Environment(\.openWindow) private var openWindow
    @State private var gameWindow: NSWindow?

    var body: some Scene {
        WindowGroup(id: "game-window") {
            GameView()
                .background(DuneWindowAccessor(window: $gameWindow))
                .onAppear {
                    openWindow(id: "tools-window")
                }
        }
        .defaultPosition(.topLeading)
        .onChange(of: gameWindow, perform: { newWindow in
            newWindow?.contentAspectRatio = NSSize(width: 320, height: 200)
        })
        
        Window("Tools", id: "tools-window") {
            StatsView()
        }
        .commands { CommandGroup(replacing: .appInfo) { } }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact)
        .windowResizability(.contentSize)
        .defaultPosition(.trailing)
    }
}
