//
//  SwiftDuneApp.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 21/08/2023.
//

import Cocoa
import SwiftUI

class GameViewController: NSViewController {
  let engine = DuneEngine.shared
  var mouse = Mouse()
  var keyboard = Keyboard()
  
  override func viewDidLoad() {
    super.viewDidLoad()

    EventManager.appStateChangedEvent.addListener(self) { [weak self] event in
        guard let self = self else {
            return
        }
  
        self.exitProgram(event)
    }
    
    engine.renderer.metalView.translatesAutoresizingMaskIntoConstraints = false

    view.addSubview(engine.renderer.metalView)

    NSLayoutConstraint.activate([
      engine.renderer.metalView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      engine.renderer.metalView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      engine.renderer.metalView.topAnchor.constraint(equalTo: view.topAnchor),
      engine.renderer.metalView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
    ])
    
    view.needsLayout = true
    view.layoutSubtreeIfNeeded()

    engine.input.registerInputMethod(keyboard)
    engine.input.registerInputMethod(mouse)
    mouse.track(engine.renderer.metalView)

    // Attach main node to the engine
    engine.rootNode.attachNode(Main())
    engine.rootNode.setNodeActive("Main", true)
  }
  
  
  func startEngine() {
    engine.run()
  }
  
  
  func stopEngine() {
    engine.stop()
  }
  
  
  func exitProgram(_ e: AppStateEventData) {
      for window in NSApplication.shared.windows {
          window.close()
      }
      
      let alert = NSAlert()
      alert.messageText = "Dune"
    
      if let message = e.message {
          alert.informativeText = message
      }

      alert.alertStyle = .informational
      alert.addButton(withTitle: "OK")
      alert.runModal()

      exit(1)
  }
}



class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var window: NSWindow!
    var gameViewController: GameViewController!
    var windowSize = NSSize(width: 640, height: 400)

    private var statsPanel: NSPanel?
    private var statsMenuItem: NSMenuItem?
    private var didPlaceStatsPanel = false
  
    func applicationDidFinishLaunching(_ notification: Notification) {
        installMainMenu()

        // Set up the main window
        window = NSWindow(
          contentRect: NSRect(origin: .zero, size: windowSize),
          styleMask: [.titled, .closable, .resizable],
          backing: .buffered,
          defer: false
        )
        window.title = "Dune"
        window.titlebarAppearsTransparent = false
        window.minSize = windowSize
        window.contentAspectRatio = windowSize

        // Set up the main view controller
        gameViewController = GameViewController()
        window.contentViewController = gameViewController
        
        // Make window visible
        window.center()
        window.makeKeyAndOrderFront(nil)

        // Run game
        gameViewController.startEngine()
    }
  
    
    func applicationWillTerminate(_ notification: Notification) {
        gameViewController.stopEngine()
    }
  
  
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return false
    }


    private func installMainMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu(title: "Dune")
        appMenuItem.submenu = appMenu

        let statsItem = NSMenuItem(
            title: "Stats",
            action: #selector(toggleStatsPanel(_:)),
            keyEquivalent: ""
        )
        statsItem.target = self
        appMenu.addItem(statsItem)
        statsMenuItem = statsItem

        appMenu.addItem(.separator())

        appMenu.addItem(NSMenuItem(
            title: "Quit Dune",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))

        mainMenu.addItem(appMenuItem)
        NSApp.mainMenu = mainMenu
    }


    @objc private func toggleStatsPanel(_ sender: NSMenuItem) {
        let panel = statsPanel ?? makeStatsPanel()
        statsPanel = panel

        if panel.isVisible {
            panel.orderOut(nil)
            panel.contentViewController = nil
            sender.state = .off
            return
        }

        panel.contentViewController = NSHostingController(rootView: StatsView())
        placeStatsPanelIfNeeded(panel)
        panel.orderFront(nil)
        sender.state = .on
    }


    private func makeStatsPanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 290, height: 460),
            styleMask: [.titled, .closable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.title = "Stats"
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.delegate = self
        return panel
    }


    private func placeStatsPanelIfNeeded(_ panel: NSPanel) {
        guard !didPlaceStatsPanel else {
            return
        }

        didPlaceStatsPanel = true

        guard let gameFrame = window?.frame else {
            panel.center()
            return
        }

        var origin = NSPoint(x: gameFrame.maxX + 12, y: gameFrame.maxY - panel.frame.height)

        if let screen = window.screen ?? NSScreen.main {
            let visible = screen.visibleFrame
            if origin.x + panel.frame.width > visible.maxX {
                origin.x = max(visible.minX, gameFrame.minX - panel.frame.width - 12)
            }
            origin.y = min(max(origin.y, visible.minY), visible.maxY - panel.frame.height)
        }

        panel.setFrameOrigin(origin)
    }


    func windowWillClose(_ notification: Notification) {
        guard let closed = notification.object as? NSWindow, closed === statsPanel else {
            return
        }

        statsPanel?.contentViewController = nil
        statsMenuItem?.state = .off
    }
}


@main struct DuneMacApp {
    static func main() throws {
        let delegate = AppDelegate()
        NSApplication.shared.delegate = delegate
        _ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
    }
}
