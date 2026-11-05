//
//  BiometricEnablementModelTests.swift
//  ChristmasTrackerTests
//
//  Tests for Story I2b-2a S3: BiometricEnablementModel with the updated
//  init(authenticator:enrollAction:) interface.
//
//  RED-phase: B1–B4 will fail to compile until BiometricEnablementModel is updated
//  to replace `init(authenticator:preference:)` with
//  `init(authenticator:enrollAction:)` per the Gate 1 spec.
//
//  Concurrency: suite is @MainActor because BiometricEnablementModel is @MainActor.
//  FakeBiometricAuthenticator.authenticate() returns synchronously — no real sleeps.
//

import Testing
@testable import ChristmasTracker

@Suite("BiometricEnablementModel Tests")
@MainActor
struct BiometricEnablementModelTests {

    // MARK: - Factory

    /// Returns a fresh SUT using the new enrollAction initialiser.
    /// `enrollAction` defaults to a no-op; pass a non-nil `actionError` to make it throw.
    /// `enrollCallCount` is incremented each time the action is invoked.
    private func makeSUT(
        result: BiometricResult = .success,
        actionError: Error? = nil
    ) -> (sut: BiometricEnablementModel, auth: FakeBiometricAuthenticator, callCount: Box<Int>) {
        let auth = FakeBiometricAuthenticator()
        auth.stubbedResult = result
        let callCount = Box(0)
        let error = actionError
        let sut = BiometricEnablementModel(authenticator: auth) {
            callCount.value += 1
            if let e = error { throw e }
        }
        return (sut, auth, callCount)
    }

    // MARK: - B1: success calls enrollAction and sets state = .succeeded

    @Test("B1: enable() with success calls enrollAction and sets state to .succeeded")
    func enableSuccessCallsEnrollActionAndSetsSucceeded() async {
        let (sut, _, callCount) = makeSUT(result: .success)
        #expect(sut.state == .idle, "Precondition: state must start .idle")

        await sut.enable()

        #expect(sut.state == .succeeded,
                "state must be .succeeded after enable() with .success")
        #expect(callCount.value == 1,
                "enrollAction must be called exactly once on success")
    }

    // MARK: - B2: .userCancelled does NOT call enrollAction; state = .idle

    @Test("B2: enable() with userCancelled does not call enrollAction; state remains .idle")
    func enableUserCancelledDoesNotCallEnrollAction() async {
        let (sut, _, callCount) = makeSUT(result: .userCancelled)

        await sut.enable()

        #expect(sut.state == .idle,
                "state must remain .idle after enable() with .userCancelled")
        #expect(callCount.value == 0,
                "enrollAction must NOT be called when authentication was cancelled")
    }

    // MARK: - B3: .failed does NOT call enrollAction; state = .failed(...)

    @Test("B3: enable() with failed does not call enrollAction; state is .failed")
    func enableFailedDoesNotCallEnrollAction() async {
        let (sut, _, callCount) = makeSUT(result: .failed)

        await sut.enable()

        if case .failed = sut.state { } else {
            #expect(Bool(false), "state must be .failed after enable() with .failed, got \(sut.state)")
        }
        #expect(callCount.value == 0,
                "enrollAction must NOT be called when biometric authentication failed")
    }

    // MARK: - B4: .success but enrollAction throws → state = .failed(...)

    @Test("B4: enable() with success but enrollAction throws sets state to .failed")
    func enableSuccessButEnrollActionThrowsSetsFailedState() async {
        struct EnrollError: Error {}
        let (sut, _, callCount) = makeSUT(result: .success, actionError: EnrollError())

        await sut.enable()

        if case .failed = sut.state { } else {
            #expect(Bool(false), "state must be .failed when enrollAction throws, got \(sut.state)")
        }
        #expect(callCount.value == 1,
                "enrollAction must be called even if it then throws (the throw is what causes .failed)")
    }

    // MARK: - Regression: systemCancelled leaves state .idle

    @Test("enable() with systemCancelled leaves state .idle")
    func enableSystemCancelledLeavesIdle() async {
        let (sut, _, callCount) = makeSUT(result: .systemCancelled)
        await sut.enable()
        #expect(sut.state == .idle)
        #expect(callCount.value == 0)
    }

    // MARK: - Regression: .lockedOut sets state to .failed

    @Test("enable() with lockedOut sets state to .failed")
    func enableLockedOutSetsFailedState() async {
        let (sut, _, _) = makeSUT(result: .lockedOut)
        await sut.enable()
        if case .failed = sut.state { } else {
            #expect(Bool(false), "state must be .failed for .lockedOut, got \(sut.state)")
        }
    }

    // MARK: - Regression: reset() after succeeded returns to .idle

    @Test("reset() after succeeded sets state back to .idle")
    func resetFromSucceededSetsIdle() async {
        let (sut, _, _) = makeSUT(result: .success)
        await sut.enable()
        #expect(sut.state == .succeeded, "Precondition: state must be .succeeded before reset")
        sut.reset()
        #expect(sut.state == .idle)
    }
}

// MARK: - Box helper

/// Simple reference-type wrapper so the closure can mutate an integer counter
/// without capturing an `inout` variable (not allowed in closures).
private final class Box<T> {
    var value: T
    init(_ value: T) { self.value = value }
}
