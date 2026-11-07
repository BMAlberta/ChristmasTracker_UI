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
/// @unchecked Sendable: the only state is `value`. It is written on the main actor during
/// composition (ChristmasTrackerApp.init, or a test) before any request is made, and is read
/// only by the seam closures, which run on the main actor before touching the service.
/// The session-end guard lives in AuthenticationService, not here.
final class AuthServiceBox: @unchecked Sendable {
    // nonisolated(unsafe): written on the main actor during composition, before the client
    // makes any request; read by the seam closures afterwards. There is no concurrent write.
    // Weak: the box must not keep the service alive (no retain cycle through the client).
    nonisolated(unsafe) weak var value: AuthenticationService?

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

    // Only forwards, on the main actor. AuthenticationService.handleServerSessionEnd checks the
    // signed-in state and the request token (stale responses are ignored there), and its
    // endSession owns the single session-end guard. A server end never touches the biometric
    // credential store. With no service, there is no session to end.
    let sessionEnding = SessionEndingSeam(onSessionEnded: { @MainActor [box] reason, requestToken in
        await box.value?.handleServerSessionEnd(reason: reason, requestToken: requestToken)
    })

    return ClientSeams(
        box: box,
        tokenProvider: tokenProvider,
        sessionRefresher: sessionRefresher,
        sessionEnding: sessionEnding
    )
}
