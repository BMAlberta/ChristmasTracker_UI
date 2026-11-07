// SessionEndingSeam.swift — SessionEnding implementation.
// Closure-injected for testability; the production closure is built by makeClientSeams()
// (ClientSeams.swift) and signs out a signed-in AuthenticationService.
import Foundation
import TrackerAPI

final class SessionEndingSeam: SessionEnding {
    private let onSessionEnded: @Sendable (SessionEndReason) async -> Void

    init(onSessionEnded: @escaping @Sendable (SessionEndReason) async -> Void) {
        self.onSessionEnded = onSessionEnded
    }

    /// Awaits the injected action, so the sign-out has finished when this returns.
    func sessionEnded(reason: SessionEndReason) async {
        await onSessionEnded(reason)
    }
}
