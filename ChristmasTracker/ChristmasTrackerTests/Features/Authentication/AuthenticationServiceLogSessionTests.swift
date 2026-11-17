//
//  AuthenticationServiceLogSessionTests.swift
//  ChristmasTrackerTests
//
//  LG1-L3 batch D (gate 2 follow-up): the biometric credential-store paths, the refresh
//  credential-failure sequence (refresh failed, then the session-end logout), and a second
//  logout while one is in flight. Shares the harness in AuthenticationServiceLogTests.swift.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("AuthenticationService session log Tests", .timeLimit(.minutes(1)))
@MainActor
struct AuthenticationServiceLogSessionTests {

    private let biometric = "auth biometric sign-in"

    // MARK: - Biometric credential store

    @Test("a cancelled biometric prompt logs started then cancelled and no error")
    func biometricUserCancelled() async {
        let rig = await AuthLogRig.prepared(.biometric)
        rig.store.stubbedReadError = .userCancelled

        await rig.run(.biometric)

        #expect(rig.messages == ["\(biometric) started", "\(biometric) cancelled"])
        #expect(rig.errors.isEmpty)
        #expect(!rig.messages.contains("\(biometric) failed"))
        rig.expectClean()
    }

    @Test("a Release-style cancelled biometric prompt logs nothing")
    func biometricUserCancelledRelease() async {
        let rig = await AuthLogRig.prepared(.biometric, verbose: false)
        rig.store.stubbedReadError = .userCancelled

        await rig.run(.biometric)
        await rig.settle()

        #expect(rig.sink.lines.isEmpty)
    }

    @Test("any other credential-store error logs exactly one failed line",
          arguments: [BiometricCredentialError.lockedOut, .biometricFailed, .itemNotFound, .itemInvalidated, .other])
    func biometricStoreError(error: BiometricCredentialError) async {
        let rig = await AuthLogRig.prepared(.biometric)
        rig.store.stubbedReadError = error

        await rig.run(.biometric)

        #expect(rig.errors == ["\(biometric) failed"])
        #expect(!rig.messages.contains("\(biometric) cancelled"))
        #expect(!rig.messages.contains("\(biometric) processed"))
        rig.expectClean()
    }

    // MARK: - Refresh credential failure

    @Test("a credential-failure refresh logs one refresh failed; a succeeding logout adds no error")
    func credentialFailureRefreshLogoutSucceeds() async {
        let rig = await AuthLogRig.prepared(.refresh)
        rig.fail(.refresh, with: AuthenticationError.invalidRefreshToken)

        await rig.run(.refresh)
        await rig.settle()

        #expect(rig.errors == ["auth refresh failed"])
        #expect(rig.service.isAuthenticated == false)
        rig.expectClean()
    }

    @Test("a credential-failure refresh then a failing logout API logs refresh failed then logout failed")
    func credentialFailureRefreshLogoutFails() async {
        let rig = await AuthLogRig.prepared(.refresh)
        rig.fail(.refresh, with: AuthenticationError.invalidRefreshToken)
        rig.repo.logoutError = AuthLogSecretError()

        await rig.run(.refresh)
        await rig.waitUntil { rig.errors.count >= 2 }
        await rig.settle()

        #expect(rig.errors == ["auth refresh failed", "auth logout failed"])
        rig.expectClean()
    }

    // MARK: - Concurrent logout

    @Test("a second logout while one is in flight logs no extra logout lines")
    func secondLogoutWhileInFlight() async {
        let rig = await AuthLogRig.prepared(.logout)
        rig.repo.holdLogout = true

        let first = Task { @MainActor in await rig.service.logout() }
        await rig.waitUntil { rig.repo.logoutCalls >= 1 }
        let second = Task { @MainActor in await rig.service.logout() }
        await rig.settle()
        rig.repo.releaseLogout()
        await first.value
        await second.value
        await rig.waitUntil { rig.messages.contains("auth logout processed") }
        await rig.settle()

        let logoutLines = rig.messages.filter { $0.hasPrefix("auth logout") }
        #expect(logoutLines == ["auth logout started", "auth logout processed"])
        #expect(rig.repo.logoutCalls == 1)
        #expect(rig.errors.isEmpty)
    }
}
