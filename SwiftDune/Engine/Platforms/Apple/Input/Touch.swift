//
//  Touch.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 13/10/2026.
//

#if os(iOS)
import UIKit

final class Touch: DuneInputMethod {
    let inputMethodType: DuneInputMethodType = .touch
    var coordinates: DunePoint = .zero

    private let recognizer = TouchRecognizer(target: nil, action: nil)
    private var clicks = Queue<DuneClickEvent>()

    private static let gameWidth: CGFloat = 320
    private static let gameHeight: CGFloat = 200

    init() {
        recognizer.owner = self
    }


    func update(_ input: Input) {
        while let click = clicks.dequeueFirst() {
            input.enqueueEvent(click)
        }
    }


    /// Tracks a single finger on `view` and maps it into the 320×200 game frame.
    func track(_ view: UIView) {
        if recognizer.view === view {
            return
        }

        view.isUserInteractionEnabled = true
        view.isMultipleTouchEnabled = false
        view.addGestureRecognizer(recognizer)
    }


    fileprivate func processTouch(_ point: CGPoint, in view: UIView, ended: Bool) {
        let bounds = view.bounds

        guard bounds.width > 0, bounds.height > 0, bounds.contains(point) else {
            coordinates.reset()
            return
        }

        let x = Int16(point.x / bounds.width * Touch.gameWidth)
        let y = Int16(point.y / bounds.height * Touch.gameHeight)
        coordinates.x = min(max(x, 0), 319)
        coordinates.y = min(max(y, 0), 199)

        if ended {
            clicks.enqueue(DuneClickEvent(point: coordinates))
        }
    }


    fileprivate func cancelTouch() {
        coordinates.reset()
    }
}


private final class TouchRecognizer: UIGestureRecognizer {
    weak var owner: Touch?

    override init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        cancelsTouchesInView = true
        delaysTouchesBegan = false
        delaysTouchesEnded = false
    }


    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)

        guard touches.count == 1, let view, let point = touches.first?.location(in: view) else {
            state = .failed
            owner?.cancelTouch()
            return
        }

        state = .began
        owner?.processTouch(point, in: view, ended: false)
    }


    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)

        guard let view, let point = touches.first?.location(in: view) else {
            return
        }

        state = .changed
        owner?.processTouch(point, in: view, ended: false)
    }


    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)

        guard let view, let point = touches.first?.location(in: view) else {
            state = .cancelled
            owner?.cancelTouch()
            return
        }

        state = .ended
        owner?.processTouch(point, in: view, ended: true)
    }


    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
        state = .cancelled
        owner?.cancelTouch()
    }
}
#endif
