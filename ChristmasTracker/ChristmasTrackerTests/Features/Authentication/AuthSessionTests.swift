// AuthSessionTests.swift
// ChristmasTrackerTests
// Copyright © 2026 BMAlberta. All rights reserved.
//
// Story C1 — failing tests for AuthSession struct and AuthTokens.needsRefresh.
// These tests will not compile until the implementer creates AuthSession.

import Testing
import Foundation
@testable import ChristmasTracker

@Suite("AuthSession")
struct AuthSessionTests {

    // MARK: Helpers

    private func makeUser() -> User {
        User(
            id: "u1",
            email: "user@test.invalid",
            firstName: "Alice",
            lastName: "Smith",
            displayName: "Alice Smith",
            role: .viewer,
            isActive: true,
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0),
            lastLoginAt: nil
        )
    }

    // MARK: AC29: expiresIn is preserved

    @Test("AuthSession preserves the expiresIn value passed at init")
    func authSessionPreservesExpiresIn() {
        let session = AuthSession(
            user: makeUser(),
            accessToken: "tok-access-FAKE",
            refreshToken: "tok-refresh-FAKE",
            expiresIn: 1800
        )

        #expect(session.expiresIn == 1800)
    }

    // MARK: AC30: AuthTokens.needsRefresh is false when well within window

    @Test("AuthTokens.needsRefresh is false when expiresAt is 900s in the future")
    func authTokensNeedsRefreshFalseWhenWellWithinWindow() {
        // expiresAt = now + 900 seconds; needsRefresh threshold is 5 min (300s) before expiry.
        // With 900s remaining, the threshold is not yet crossed.
        let tokens = AuthTokens(
            accessToken: "tok-access-FAKE",
            refreshToken: "tok-refresh-FAKE",
            expiresAt: Date(timeIntervalSinceNow: 900)
        )

        #expect(tokens.needsRefresh == false)
    }

    // MARK: Additional: AuthSession stores user

    @Test("AuthSession stores the user passed at init")
    func authSessionStoresUser() {
        let user = makeUser()
        let session = AuthSession(
            user: user,
            accessToken: "tok-access-FAKE",
            refreshToken: "tok-refresh-FAKE",
            expiresIn: 900
        )

        #expect(session.user.id == "u1")
        #expect(session.user.email == "user@test.invalid")
    }

    // MARK: Additional: AuthSession is Sendable (compile-time check)

    @Test("AuthSession is Sendable — can be passed across concurrency boundaries")
    func authSessionIsSendable() async {
        let session = AuthSession(
            user: makeUser(),
            accessToken: "tok-access-FAKE",
            refreshToken: "tok-refresh-FAKE",
            expiresIn: 900
        )
        // Simply hand to a Task to verify Sendable conformance at compile time
        let result = await Task.detached {
            session.expiresIn
        }.value

        #expect(result == 900)
    }
}
