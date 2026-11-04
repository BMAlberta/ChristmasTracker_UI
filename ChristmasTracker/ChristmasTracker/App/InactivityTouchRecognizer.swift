//
//  InactivityTouchRecognizer.swift
//  ChristmasTracker
//
//  A UIGestureRecognizer that records touch activity without interfering with the
//  responder chain. Always transitions to .failed; never consumes touches.
//

@preconcurrency import UIKit

/// Passive touch recognizer that calls `activityHandler` on every touchesBegan event,
/// then immediately fails so it never claims ownership of the touch.
internal final class InactivityTouchRecognizer: UIGestureRecognizer {

    // MARK: - Properties

    var activityHandler: (() -> Void)?

    // MARK: - Init

    override init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        cancelsTouchesInView = false
        delaysTouchesBegan = false
        delaysTouchesEnded = false
        delegate = self
    }

    // MARK: - UIGestureRecognizer

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        activityHandler?()
        state = .failed
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
    }
}

// MARK: - UIGestureRecognizerDelegate

extension InactivityTouchRecognizer: UIGestureRecognizerDelegate {

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        return true
    }
}
