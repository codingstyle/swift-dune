//
//  DuneIOSApp.swift
//  SwiftDune (iOS)
//
//  iOS front end. The engine, scenes and resources are shared with the macOS
//  target; this file replaces DuneGameApp.swift (AppKit window + NSEvent
//  monitors) with a UIKit scene, touch input and on-screen keys.
//
//  Input mapping (see IOS_PORT.md):
//  - tap on the picture        -> mouse click at that game pixel
//  - drag on the picture       -> mouse hover (menu highlight)
//  - swipe on the picture      -> arrow key (room / desert / globe moves)
//  - side buttons              -> the keys Game.onKey and Main.onKey react to
//  - hardware keyboard         -> same keys as on the Mac
//

import UIKit
import MetalKit


@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: "Default", sessionRole: connectingSceneSession.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }
}


final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = GameViewController()
        window.makeKeyAndVisible()
        self.window = window
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        DuneEngine.shared.pause()
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        let engine = DuneEngine.shared
        if !engine.isRunning {
            engine.run()
        }
    }
}


final class GameViewController: UIViewController {
    private let engine = DuneEngine.shared
    private var gameView: MTKView { engine.renderer.metalView }

    private let leftColumn = UIStackView()
    private let rightColumn = UIStackView()

    /// Width reserved for each button column; the picture takes the rest.
    private let columnWidth: CGFloat = 52.0

    private var swipeStart: CGPoint?
    private var touchMoved = false


    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .landscape }
    override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge { .all }
    override var canBecomeFirstResponder: Bool { true }


    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        gameView.isMultipleTouchEnabled = false
        gameView.isUserInteractionEnabled = false  // touches handled by this controller
        view.addSubview(gameView)

        configureColumn(leftColumn, keys: [
            ("ESC", DuneKeyEvent(specialKey: .keyEscape)),
            ("⏎", DuneKeyEvent(specialKey: .keyReturn)),
            ("BOOK", DuneKeyEvent(char: "b")),
            ("MAP", DuneKeyEvent(char: "m")),
            ("ORDR", DuneKeyEvent(char: "o")),
            ("RSLT", DuneKeyEvent(char: "r")),
            ("GLOB", DuneKeyEvent(char: "g")),
            ("PROS", DuneKeyEvent(char: "p")),
        ])
        configureColumn(rightColumn, keys: [
            ("▲", DuneKeyEvent(specialKey: .keyUp)),
            ("◀", DuneKeyEvent(specialKey: .keyLeft)),
            ("▶", DuneKeyEvent(specialKey: .keyRight)),
            ("▼", DuneKeyEvent(specialKey: .keyDown)),
            ("SPC", DuneKeyEvent(char: " ")),
        ])

        engine.logger.log(.info, "iOS front end started")

        // Attach main node to the engine (same as the macOS GameViewController)
        engine.rootNode.attachNode(Main())
        engine.rootNode.setNodeActive("Main", true)
        engine.run()
    }


    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        becomeFirstResponder()
    }


    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        let safe = view.bounds.inset(by: view.safeAreaInsets)
        let available = safe.insetBy(dx: columnWidth + 4.0, dy: 0.0)

        // Keep the 320x200 frame at 16:10 like the macOS window (640x400).
        var width = available.width
        var height = width * 10.0 / 16.0
        if height > available.height {
            height = available.height
            width = height * 16.0 / 10.0
        }

        gameView.frame = CGRect(x: available.midX - width / 2.0,
                                y: available.midY - height / 2.0,
                                width: width, height: height).integral

        leftColumn.frame = CGRect(x: safe.minX, y: safe.minY, width: columnWidth, height: safe.height)
        rightColumn.frame = CGRect(x: safe.maxX - columnWidth, y: safe.minY, width: columnWidth, height: safe.height)

        engine.logger.log(.info, "layout view=\(view.bounds) safe=\(safe) game=\(gameView.frame) drawable=\(gameView.drawableSize)")
    }


    private func configureColumn(_ column: UIStackView, keys: [(String, DuneKeyEvent)]) {
        column.axis = .vertical
        column.distribution = .fillEqually
        column.spacing = 4.0
        view.addSubview(column)

        for (title, key) in keys {
            var config = UIButton.Configuration.filled()
            config.title = title
            config.baseBackgroundColor = UIColor(white: 0.18, alpha: 1.0)
            config.baseForegroundColor = UIColor(red: 0.95, green: 0.78, blue: 0.45, alpha: 1.0)
            config.contentInsets = .zero
            config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
                var attributes = attributes
                attributes.font = UIFont.monospacedSystemFont(ofSize: 11.0, weight: .bold)
                return attributes
            }

            let button = UIButton(configuration: config, primaryAction: UIAction { [weak self] _ in
                self?.engine.keyboard.push(key)
            })
            button.accessibilityLabel = title
            column.addArrangedSubview(button)
        }
    }


    // MARK: - Touch → mouse / swipe → arrows

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: gameView)
        guard gameView.bounds.contains(location) else { return }

        swipeStart = location
        touchMoved = false
        engine.mouse.updateTouch(location, in: gameView.bounds, ended: false)
    }


    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, let start = swipeStart else { return }
        let location = touch.location(in: gameView)

        if hypot(location.x - start.x, location.y - start.y) > 12.0 {
            touchMoved = true
        }
        engine.mouse.updateTouch(location, in: gameView.bounds, ended: false)
    }


    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, let start = swipeStart else { return }
        let location = touch.location(in: gameView)
        swipeStart = nil

        let dx = location.x - start.x
        let dy = location.y - start.y
        let swipeDistance = min(gameView.bounds.width, gameView.bounds.height) * 0.2

        if max(abs(dx), abs(dy)) >= swipeDistance {
            // Swipe the picture the way you want to walk.
            let key: DuneSpecialKey = abs(dx) > abs(dy)
                ? (dx > 0 ? .keyRight : .keyLeft)
                : (dy > 0 ? .keyDown : .keyUp)
            engine.keyboard.push(DuneKeyEvent(specialKey: key))
            return
        }

        // A short drag is still a click, at the point where the finger lifted
        // (menu rows highlight under the finger while it moves).
        engine.mouse.updateTouch(touchMoved ? location : start, in: gameView.bounds, ended: true)
    }


    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        swipeStart = nil
    }


    // MARK: - Hardware keyboard

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        var handled = false

        for press in presses {
            guard let key = press.key else { continue }

            var keyEvent = DuneKeyEvent()
            switch key.keyCode {
            case .keyboardEscape: keyEvent.specialKey = .keyEscape
            case .keyboardReturnOrEnter, .keypadEnter: keyEvent.specialKey = .keyReturn
            case .keyboardDeleteOrBackspace: keyEvent.specialKey = .keyDelete
            case .keyboardLeftArrow: keyEvent.specialKey = .keyLeft
            case .keyboardRightArrow: keyEvent.specialKey = .keyRight
            case .keyboardUpArrow: keyEvent.specialKey = .keyUp
            case .keyboardDownArrow: keyEvent.specialKey = .keyDown
            default:
                guard let first = key.characters.first else { continue }
                keyEvent.char = String(first)
            }

            engine.keyboard.push(keyEvent)
            handled = true
        }

        if !handled {
            super.pressesBegan(presses, with: event)
        }
    }
}
