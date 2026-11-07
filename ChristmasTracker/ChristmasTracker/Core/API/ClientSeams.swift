// ClientSeams.swift — composition of the generated-client seams (I2b-2c U2, decision D-a).
//
// The generated client is built before AuthenticationService exists, so its seams reach the
// service through AuthServiceBox, which is filled in after the service is created.
//
// Ownership: client -> seams -> (closures, strong) -> box -> (weak) -> service.
// The closures hold the box strongly so it lives as long as the seams (the previous
// `[weak authBox]` captures let the box be freed when ChristmasTrackerApp.init returned).
// The box holds the service weakly, so there is no retain cycle.
import Foundation
import TrackerAPI

// MARK: - AuthServiceBox

/// A reference container that lets the seam closures reach AuthenticationService after it is
/// created, without a circular dependency between the client and the service.
/// @unchecked Sendable: the state is `value` and `isEndingSession`. `value` is written on the
/// main actor during composition (ChristmasTrackerApp.init, or a test) before any request is
/// made, and is read only by the seam closures, which run on the main actor before touching
/// the service. `isEndingSession` is accessed only by the @MainActor session-ending closure.
final class AuthServiceBox: @unchecked Sendable {
    // nonisolated(unsafe): written on the main actor during composition, before the client
    // makes any request; read by the seam closures afterwards. There is no concurrent write.
    // Weak: the box must not keep the service alive (no retain cycle through the client).
    nonisolated(unsafe) weak var value: AuthenticationService?

    // nonisolated(unsafe): read and written only inside the session-ending closure, which is
    // @MainActor, so every access is serialized on the main actor. No concurrent access.
    // True while a server-initiated sign-out is in progress (single-flight guard, see
    // makeClientSeams()).
    nonisolated(unsafe) var isEndingSession = false

    init() {}
}

// MARK: - ClientSeams

/// The box and the three seams handed to buildGeneratedClient.
struct ClientSeams {
    let box: AuthServiceBox
    let tokenProvider: AccessTokenSeam
    let sessionRefresher: SessionRefreshSeam
    let sessionEnding: SessionEndingSeam
}

// MARK: - makeClientSeams

/// Builds the box and the three seams. Every closure captures the box strongly.
/// Set `box.value` to the AuthenticationService once it exists.
func makeClientSeams() -> ClientSeams {
    let box = AuthServiceBox()

    let tokenProvider = AccessTokenSeam(tokenGetter: { @MainActor [box] in
        box.value?.currentAccessToken
    })

    // With no service, throw the credential failure that SessionRefreshSeam maps to
    // SessionRefreshError.credentialFailure.
    let sessionRefresher = SessionRefreshSeam(forceRefresh: { @MainActor [box] in
        guard let service = box.value else { throw AuthenticationError.invalidRefreshToken }
        try await service.forceRefresh()
    })

    // Signs out only a signed-in session, and only when the failing request carried the
    // current access token; never touches the biometric credential store.
    // Single-flight: logout suspends in the session teardown before isAuthenticated becomes
    // false, so concurrent 403/404 responses would each pass the isAuthenticated check and
    // tear the session down more than once. The flag is checked and set on the main actor
    // with no suspension in between, so only the first caller signs out; later callers
    // return while it is in flight. It is cleared after logout returns, so a later,
    // separate session end still works.
    // Stale responses: a slow 403/404 to a request made by an earlier session (for example,
    // user A's request answered after user B signed in) carries A's token, not the current
    // one, so it is ignored. A nil request token is ignored too. Trade-off: a request that
    // used a token a refresh has since rotated is also ignored; that is acceptable because
    // the next request carries the new token and gets its own 403/404, which ends the session.
    let sessionEnding = SessionEndingSeam(onSessionEnded: { @MainActor [box] reason, requestToken in
        guard !box.isEndingSession, let service = box.value, service.isAuthenticated else { return }
        guard let requestToken, requestToken == service.currentAccessToken else {
            // No token values in the log.
            LogInfo("Session end ignored: ignored a stale session-end", category: .auth)
            return
        }
        box.isEndingSession = true
        defer { box.isEndingSession = false }
        LogInfo("Session ended by the server: \(reason)", category: .auth)
        await service.logout(reason: .sessionExpired)
    })

    return ClientSeams(
        box: box,
        tokenProvider: tokenProvider,
        sessionRefresher: sessionRefresher,
        sessionEnding: sessionEnding
    )
}
