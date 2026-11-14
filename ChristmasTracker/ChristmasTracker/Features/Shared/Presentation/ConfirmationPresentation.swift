//
//  ConfirmationPresentation.swift
//  ChristmasTracker
//
//  The presentation state of one confirmation dialog, as a pure value. The screen owns it (it
//  outlives the list rows), and every change is one transition. A transition that does not apply
//  in the current state returns the value unchanged. Nothing here logs names or ids.
//

import Foundation

nonisolated struct ConfirmationPresentation<Target: Hashable & Sendable>: Equatable, Sendable {
    /// The target being confirmed; nil means idle.
    let target: Target?

    static var idle: ConfirmationPresentation {
        ConfirmationPresentation(target: nil)
    }

    var isIdle: Bool {
        target == nil
    }

    func isConfirming(_ candidate: Target) -> Bool {
        target == candidate
    }

    /// Only from idle; a request while a dialog is open is ignored.
    func requesting(_ candidate: Target) -> ConfirmationPresentation {
        guard isIdle else { return self }
        return ConfirmationPresentation(target: candidate)
    }

    func cancelled() -> ConfirmationPresentation {
        .idle
    }

    /// From confirming the same target: idle and the target to run. Anything else: unchanged, nothing to run.
    func confirmed(_ candidate: Target) -> (presentation: ConfirmationPresentation, run: Target?) {
        guard isConfirming(candidate) else { return (self, nil) }
        return (.idle, candidate)
    }

    /// Idle only when the target is no longer present; the same ids re-rendered or reloaded change nothing.
    func targetsChanged(existing: Set<Target>) -> ConfirmationPresentation {
        guard let target, !existing.contains(target) else { return self }
        return .idle
    }

    func reset() -> ConfirmationPresentation {
        .idle
    }
}
