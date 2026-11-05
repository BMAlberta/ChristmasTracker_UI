//
//  BiometricEnablementModelTests.swift
//  ChristmasTrackerTests
//
//  Tests for Story R5: BiometricEnablementModel — drives the biometric enablement
//  flow and maps BiometricResult cases to EnablementState transitions.
//
//  RED-phase: will fail to compile until BiometricEnablementModel is added to the
//  production module (cannot find type 'BiometricEnablementModel' in scope).
//
//  Concurrency: suite is @MainActor because BiometricEnablementModel is @MainActor.
//  No real sleeps — FakeBiometricAuthenticator.authenticate returns synchronously.
//

import Testing
@testable import ChristmasTracker

@Suite("BiometricEnablementModel Tests")
@MainActor
struct BiometricEnablementModelTests {

    // MARK: - Factory

    /// Returns a fresh SUT pre-configured with the given stubbed result.
    /// The returned preference fake lets callers inspect side-effects.
    private func makeSUT(
        result: BiometricResult = .success
    ) -> (sut: BiometricEnablementModel, auth: FakeBiometricAuthenticator, pref: FakeBiometricUnlockPreference) {
        let auth = FakeBiometricAuthenticator()
        auth.stubbedResult = result
        let pref = FakeBiometricUnlockPreference()
        let sut = BiometricEnablementModel(authenticator: auth, preference: pref)
        return (sut, auth, pref)
    }

    // MARK: - Tests

    @Test("enable() calls the authenticator")
    func enableCallsAuthenticator() async {
        let (sut, _, _) = makeSUT(result: .success)
        // State starts idle; after enable() it must have changed (authenticator was called).
        #expect(sut.state == .idle)
        await sut.enable()
        // If authenticator was called the state will have advanced past .idle.
        #expect(sut.state != .idle)
    }

    @Test("enable() with .success sets preference.biometricUnlockEnabled and state .succeeded")
    func enableSuccessSetsPreferenceAndSucceededState() async {
        let (sut, _, pref) = makeSUT(result: .success)
        await sut.enable()
        #expect(sut.state == .succeeded)
        #expect(pref.biometricUnlockEnabled == true)
    }

    @Test("enable() with .userCancelled leaves state .idle and preference unchanged")
    func enableUserCancelledStaysIdleAndLeavesPreferenceUnchanged() async {
        let (sut, _, pref) = makeSUT(result: .userCancelled)
        await sut.enable()
        #expect(sut.state == .idle)
        #expect(pref.biometricUnlockEnabled == false)
    }

    @Test("enable() with .systemCancelled leaves state .idle")
    func enableSystemCancelledStaysIdle() async {
        let (sut, _, _) = makeSUT(result: .systemCancelled)
        await sut.enable()
        #expect(sut.state == .idle)
    }

    @Test("enable() with .failed sets state to .failed(_)")
    func enableFailedSetsFailedState() async {
        let (sut, _, _) = makeSUT(result: .failed)
        await sut.enable()
        if case .failed = sut.state { } else {
            #expect(Bool(false), "Expected state to be .failed but got \(sut.state)")
        }
    }

    @Test("enable() with .lockedOut sets state to .failed(_)")
    func enableLockedOutSetsFailedState() async {
        let (sut, _, _) = makeSUT(result: .lockedOut)
        await sut.enable()
        if case .failed = sut.state { } else {
            #expect(Bool(false), "Expected state to be .failed but got \(sut.state)")
        }
    }

    @Test("enable() with .unavailable sets state to .failed(_)")
    func enableUnavailableSetsFailedState() async {
        let (sut, _, _) = makeSUT(result: .unavailable)
        await sut.enable()
        if case .failed = sut.state { } else {
            #expect(Bool(false), "Expected state to be .failed but got \(sut.state)")
        }
    }

    @Test("enable() with .userFallback sets state to .failed(_)")
    func enableUserFallbackSetsFailedState() async {
        let (sut, _, _) = makeSUT(result: .userFallback)
        await sut.enable()
        if case .failed = sut.state { } else {
            #expect(Bool(false), "Expected state to be .failed but got \(sut.state)")
        }
    }

    @Test("enable() with .failed does not set biometricUnlockEnabled")
    func enableFailedDoesNotSetBiometricUnlockEnabled() async {
        let (sut, _, pref) = makeSUT(result: .failed)
        await sut.enable()
        #expect(pref.biometricUnlockEnabled == false)
    }

    @Test("reset() after succeeded sets state back to .idle")
    func resetFromSucceededSetsIdle() async {
        let (sut, _, _) = makeSUT(result: .success)
        await sut.enable()
        #expect(sut.state == .succeeded, "Precondition: state must be .succeeded before reset")
        sut.reset()
        #expect(sut.state == .idle)
    }
}
