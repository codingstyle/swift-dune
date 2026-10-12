//
//  DuneIOSApp.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 11/10/2026.
//

import SwiftUI
import UIKit

final class GameViewController: UIViewController {
    let engine = DuneEngine.shared

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .black

        let metalView = engine.renderer.metalView
        metalView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(metalView)

        let matchWidth = metalView.widthAnchor.constraint(equalTo: view.widthAnchor)
        let matchHeight = metalView.heightAnchor.constraint(equalTo: view.heightAnchor)
        matchWidth.priority = .defaultHigh
        matchHeight.priority = .defaultHigh

        NSLayoutConstraint.activate([
            metalView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            metalView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            metalView.widthAnchor.constraint(equalTo: metalView.heightAnchor, multiplier: 8.0 / 5.0),
            metalView.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor),
            metalView.heightAnchor.constraint(lessThanOrEqualTo: view.heightAnchor),
            matchWidth,
            matchHeight
        ])

        engine.input.mouseEnabled = false
        engine.rootNode.attachNode(Main())
        engine.rootNode.setNodeActive("Main", true)
    }


    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startEngine()
    }


    override var prefersStatusBarHidden: Bool {
        true
    }


    override var prefersHomeIndicatorAutoHidden: Bool {
        true
    }


    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        .landscape
    }


    func startEngine() {
        guard !engine.isRunning else {
            return
        }

        engine.run()
    }


    func stopEngine() {
        engine.stop()
    }
}


final class AppDelegate: NSObject, UIApplicationDelegate {
    func applicationWillTerminate(_ application: UIApplication) {
        DuneEngine.shared.stop()
    }
}


struct GameView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> GameViewController {
        GameViewController()
    }

    func updateUIViewController(_ uiViewController: GameViewController, context: Context) {
    }
}


@main
struct DuneIOSApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            GameView()
                .ignoresSafeArea()
                .statusBarHidden(true)
                .persistentSystemOverlays(.hidden)
        }
    }
}
