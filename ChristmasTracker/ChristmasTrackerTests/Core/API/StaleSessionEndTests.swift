// StaleSessionEndTests.swift
// ChristmasTrackerTests
//
// Package I2b-2d, story E1: a stale 403 or 404 cannot sign out the next user.
//
// End to end through the real composition: the seams come from makeClientSeams(), the box is
// attached to a real AuthenticationService built from fakes, and the generated client comes
// from TrackerClientFactory.make with a fake transport defined in this file.
//
// - Two users: user A signs in and starts getCurrentUser; the transport holds A's request
//   (it signals that the request arrived and suspends until the test releases it). While it
//   is held, A logs out and B signs in. The test then releases a 403 ACCOUNT_DISABLED for
//   A's request. B must still be signed in, the teardown must not run again, and the Face ID
//   enrollment must be untouched.
// - Composition: a 403 ACCOUNT_DISABLED (or 404 USER_NOT_FOUND) on getCurrentUser for the
//   signed-in user's own token ends the session once.
//
// Deterministic handshake only: continuations, no sleeps, no yield loops.
// No real Keychain-backed credential store, no LocalAuthentication, no network: the service
// uses MockAuthenticationRepository, FakeBiometricAuthenticator, FakeLegacyTokenCleanup,
// InMemoryBiometricCredentialStore and an in-memory remembered-email store.
//
// Fails to compile until the implementer changes SessionEnding to
// sessionEnded(reason:requestToken:); fails at run time until the adapter compares the
// request token with the current access token and SessionEnding sits inside BearerAuth.

import Testing
import Foundation
import HTTPTypes
import OpenAPIRuntime
import TrackerAPI
@testable import ChristmasTracker

// MARK: - HoldingTransport

/// Holds the first request until the test releases a response for it.
/// `waitUntilRequestArrived()` returns once a request has reached `send`.
private actor HoldingTransport: ClientTransport {
    private(set) var receivedAuthorizations: [String?] = []
    private var arrivalWaiter: CheckedContinuation<Void, Never>?
    private var heldRequest: CheckedContinuation<(HTTPResponse, HTTPBody?), Never>?
    private var earlyRelease: (HTTPResponse, HTTPBody?)?

    func send(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String
    ) async throws -> (HTTPResponse, HTTPBody?) {
        receivedAuthorizations.append(request.headerFields[.authorization])
        arrivalWaiter?.resume()
        arrivalWaiter = nil
        if let earlyRelease {
            self.earlyRelease = nil
            return earlyRelease
        }
        return await withCheckedContinuation { continuation in
            heldRequest = continuation
        }
    }

    /// Returns once a request has arrived (immediately if one already has).
    func waitUntilRequestArrived() async {
        guard receivedAuthorizations.isEmpty else { return }
        await withCheckedContinuation { continuation in
            arrivalWaiter = continuation
        }
    }

    /// Completes the held request with the given response.
    func release(_ response: HTTPResponse, body: HTTPBody?) {
        if let heldRequest {
            heldRequest.resume(returning: (response, body))
            self.heldRequest = nil
        } else {
            earlyRelease = (response, body)
        }
    }
}

// MARK: - SingleResponseTransport

/// Returns one scripted response to every request and records each Authorization header.
private actor SingleResponseTransport: ClientTransport {
    private let statusCode: Int
    private let responseBody: String
    private(set) var receivedAuthorizations: [String?] = []

    init(statusCode: Int, responseBody: String) {
        self.statusCode = statusCode
        self.responseBody = responseBody
    }

    func send(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String
    ) async throws -> (HTTPResponse, HTTPBody?) {
        receivedAuthorizations.append(request.headerFields[.authorization])
        return (HTTPResponse(status: HTTPResponse.Status(code: statusCode)), HTTPBody(responseBody))
    }
}

// MARK: - NoopVersionOutdatedHandler

private actor NoopVersionOutdatedHandler: VersionOutdatedHandling {
    func handleVersionOutdated(_ details: VersionOutdatedDetails) async {}
}

// MARK: - InMemoryEmailStore

private struct InMemoryEmailStore: RememberedEmailStoring {
    var rememberedEmail: String?
}

// MARK: - Suite

@Suite("Stale session end (I2b-2d E1)")
@MainActor
struct StaleSessionEndTests {

    // MARK: - Fixtures

    private static let password = "password-FAKE"
    private static let emailA = "alice@test.invalid"
    private static let emailB = "bob@test.invalid"
    /// MockAuthenticationRepository derives the user ID "mock-<local part>" from the email.
    private static let userIdA = "mock-alice"
    private static let userIdB = "mock-bob"

    private static func envelope(code: Int, errorCode: String, message: String) -> String {
        """
        {
          "success": false,
          "error": {
            "code": \(code),
            "errorCode": "\(errorCode)",
            "message": "\(message)",
            "details": {}
          },
          "meta": {
            "timestamp": "2026-11-07T00:00:00.000Z",
            "requestId": "req-abc123",
            "sessionId": "ses-abc123"
          }
        }
        """
    }

    private static var accountDisabled: String {
        envelope(code: 1008, errorCode: "ACCOUNT_DISABLED", message: "This account has been disabled")
    }

    private static var userNotFound: String {
        envelope(code: 4002, errorCode: "USER_NOT_FOUND", message: "User not found")
    }

    private struct SUT {
        let service: AuthenticationService
        let seams: ClientSeams
        let clearable: MockSessionClearable
        let store: InMemoryBiometricCredentialStore
    }

    /// A real AuthenticationService built from fakes, with user A's Face ID enrollment present,
    /// attached to the box of a fresh makeClientSeams().
    private func makeSUT() throws -> SUT {
        let store = InMemoryBiometricCredentialStore()
        try store.enroll(refreshToken: "mock_rt_\(Self.userIdA)_FAKE", userId: Self.userIdA, firstName: "Alice")
        let clearable = MockSessionClearable()
        let service = AuthenticationService(
            repository: MockAuthenticationRepository(),
            sessionManager: SessionManager(initialClearables: [clearable]),
            biometricAuthenticator: FakeBiometricAuthenticator(),
            emailStore: InMemoryEmailStore(),
            legacyCleanup: FakeLegacyTokenCleanup(),
            credentialStore: store
        )
        let seams = makeClientSeams()
        seams.box.value = service
        return SUT(service: service, seams: seams, clearable: clearable, store: store)
    }

    private func makeClient(seams: ClientSeams, transport: any ClientTransport) throws -> Client {
        let serverURL = try #require(URL(string: "https://api.example.com"))
        return try TrackerClientFactory.make(
            serverURL: serverURL,
            info: AppClientInfo(platform: "ios", clientPlatform: "ios", build: "1", version: "1.0.0"),
            tokenProvider: seams.tokenProvider,
            sessionRefresher: seams.sessionRefresher,
            versionOutdatedHandler: NoopVersionOutdatedHandler(),
            requestIDObserver: nil,
            sessionEndingHandler: seams.sessionEnding,
            transport: transport
        )
    }

    private func signIn(_ service: AuthenticationService, email: String, userId: String) async throws {
        await service.login(email: email, password: Self.password)
        try #require(service.isAuthenticated, "Precondition: the mock login must sign the service in")
        try #require(service.currentUser?.id == userId, "Precondition: the expected user is signed in")
    }

    // MARK: - Two users

    @Test(
        "A's 403 ACCOUNT_DISABLED, released after A logs out and B signs in, does not sign B out",
        .timeLimit(.minutes(1))
    )
    func staleAccountDisabledDoesNotSignOutNextUser() async throws {
        let sut = try makeSUT()
        let transport = HoldingTransport()
        let client = try makeClient(seams: sut.seams, transport: transport)

        // User A signs in and starts an authenticated request that the transport holds.
        try await signIn(sut.service, email: Self.emailA, userId: Self.userIdA)
        let tokenA = try #require(sut.service.currentAccessToken)
        let requestA = Task { () async throws -> Bool in
            if case .forbidden = try await client.getCurrentUser() { return true }
            return false
        }
        await transport.waitUntilRequestArrived()
        #expect(await transport.receivedAuthorizations == ["Bearer \(tokenA)"])

        // While A's request is held: A logs out, B signs in.
        await sut.service.logout()
        try #require(sut.service.isAuthenticated == false)
        try await signIn(sut.service, email: Self.emailB, userId: Self.userIdB)
        let tokenB = try #require(sut.service.currentAccessToken)
        try #require(tokenB != tokenA, "Precondition: B has a different access token from A")
        let clearsAfterBSignIn = sut.clearable.clearCallCount
        #expect(clearsAfterBSignIn == 1, "A's own logout runs the teardown once")

        // The server now answers A's request with 403 ACCOUNT_DISABLED.
        await transport.release(
            HTTPResponse(status: HTTPResponse.Status(code: 403)),
            body: HTTPBody(Self.accountDisabled)
        )
        let decodedAsForbidden = try await requestA.value

        #expect(decodedAsForbidden, "A's response still decodes as .forbidden")
        #expect(sut.service.isAuthenticated == true, "B must still be signed in")
        #expect(sut.service.currentUser?.id == Self.userIdB)
        #expect(sut.service.currentAccessToken == tokenB)
        #expect(sut.clearable.clearCallCount == clearsAfterBSignIn, "No teardown after B signed in")
        #expect(sut.store.enrolledUser()?.userId == Self.userIdA, "The Face ID enrollment is untouched")
        #expect(await transport.receivedAuthorizations.count == 1, "The 403 is not retried")
    }

    // MARK: - Composition

    @Test(
        "Composition: getCurrentUser 403 ACCOUNT_DISABLED for the signed-in user's token ends the session once",
        .timeLimit(.minutes(1))
    )
    func accountDisabledForCurrentTokenEndsSessionOnce() async throws {
        let sut = try makeSUT()
        let transport = SingleResponseTransport(statusCode: 403, responseBody: Self.accountDisabled)
        let client = try makeClient(seams: sut.seams, transport: transport)
        try await signIn(sut.service, email: Self.emailA, userId: Self.userIdA)
        let token = try #require(sut.service.currentAccessToken)

        let output = try await client.getCurrentUser()

        guard case .forbidden = output else {
            Issue.record("Expected .forbidden but got \(output)")
            return
        }
        #expect(await transport.receivedAuthorizations == ["Bearer \(token)"])
        #expect(sut.service.isAuthenticated == false)
        #expect(sut.service.currentUser == nil)
        #expect(sut.service.currentAccessToken == nil)
        #expect(sut.clearable.clearCallCount == 1)
        #expect(sut.store.enrolledUser()?.userId == Self.userIdA, "The Face ID enrollment is untouched")
    }

    @Test(
        "Composition: getCurrentUser 404 USER_NOT_FOUND for the signed-in user's token ends the session once",
        .timeLimit(.minutes(1))
    )
    func userNotFoundForCurrentTokenEndsSessionOnce() async throws {
        let sut = try makeSUT()
        let transport = SingleResponseTransport(statusCode: 404, responseBody: Self.userNotFound)
        let client = try makeClient(seams: sut.seams, transport: transport)
        try await signIn(sut.service, email: Self.emailA, userId: Self.userIdA)

        let output = try await client.getCurrentUser()

        guard case .notFound = output else {
            Issue.record("Expected .notFound but got \(output)")
            return
        }
        #expect(sut.service.isAuthenticated == false)
        #expect(sut.clearable.clearCallCount == 1)
        #expect(sut.store.enrolledUser()?.userId == Self.userIdA, "The Face ID enrollment is untouched")
    }
}
