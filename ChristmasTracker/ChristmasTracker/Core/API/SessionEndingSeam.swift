// SessionEndingSeam.swift — SessionEnding implementation.
// Closure-injected for testability; the production closure is built by makeClientSeams()
// (ClientSeams.swift) and signs out a signed-in AuthenticationService only when the failing
// request's bearer token is the current access token.
import Foundation
import TrackerAPI

final class SessionEndingSeam: SessionEnding {
    private let onSessionEnded: @Sendable (SessionEndReason, String?) async -> Void

    init(onSessionEnded: @escaping @Sendable (SessionEndReason, String?) async -> Void) {
        self.onSessionEnded = onSessionEnded
    }

    /// Awaits the injected action with the reason and the failing request's bearer token, so
    /// any sign-out has finished when this returns.
    func sessionEnded(reason: SessionEndReason, requestToken: String?) async {
        await onSessionEnded(reason, requestToken)
    }
}
