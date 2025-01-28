//
//  SwiftDuneApp.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 21/08/2023.
//

import Cocoa

class GameViewController: NSViewController {
  let engine = DuneEngine.shared
  
  override func viewDidLoad() {
    super.viewDidLoad()

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
}



class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var gameViewController: GameViewController!
    var windowSize = NSSize(width: 640, height: 400)
  
    func applicationDidFinishLaunching(_ notification: Notification) {
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
}


@main struct DuneApp {
    static func main() throws {
        let delegate = AppDelegate()
        NSApplication.shared.delegate = delegate
        _ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
    }
}
