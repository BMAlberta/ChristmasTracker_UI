//
//  BiometricAuthenticatingTests.swift
//  ChristmasTrackerTests
//
//  Tests for Story I2b-1 (Story 2): BiometricAuthenticating protocol and
//  the mapping of BiometricResult values to InactivityLockController lock state.
//
//  R1 rework: makeLockedController() helper rewritten to use FakeClock + FakeSleeper
//  instead of tracker.enteredBackground(at:), which is removed in R1.
//
//  Will fail to compile until:
//    - InactivityLockController gains clockNow: and sleepUntil: init params (R1)
//    - BiometricAuthenticating.swift is added (protocol + BiometricResult enum)
//    - FakeBiometricAuthenticator is accessible from the test target
//
//  Concurrency: all controller tests are @MainActor (controller is @MainActor).
//  No real Task.sleep — lock state is driven via fake clock + scene events (R1).
//

import Testing
import Foundation
@testable import ChristmasTracker

// MARK: - Helpers

/// Minimal in-test fake policy with a 10-minute timeout.
private struct FakePolicy10: LockTimeoutProviding {
    let timeoutMinutes: Int = 10
}

// MARK: - Suite

@Suite("BiometricAuthenticating Tests")
@MainActor
struct BiometricAuthenticatingTests {

    // MARK: - Factory

    /// Returns a fresh FakeBiometricAuthenticator with default stubs.
    private func makeSUT() -> FakeBiometricAuthenticator {
        FakeBiometricAuthenticator()
    }

    /// Returns a fresh InactivityLockController driven into .locked state using
    /// the fake clock + sceneDidBecomeActive() pattern (R1 rework).
    ///
    /// Will fail to compile until InactivityLockController gains clockNow: and
    /// sleepUntil: init params.
    private func makeLockedController() -> InactivityLockController {
        let clock = FakeClock()
        let sleeper = FakeSleeper()
        let controller = InactivityLockController(
            policy: FakePolicy10(),
            clockNow: { clock.now },
            sleepUntil: { deadline in try await sleeper.sleep(until: deadline) }
        )
        controller.start()
        // Advance fake clock past the 10-minute deadline.
        clock.advance(by: .seconds(10 * 60 + 1))
        // sceneDidBecomeActive checks isTimedOut(at: clock.now) → true → locks.
        controller.sceneDidBecomeActive()
        return controller
    }

    // MARK: - FakeBiometricAuthenticator defaults

    @Test("FakeBiometricAuthenticator.isAvailable defaults to true")
    func fakeIsAvailableDefaultsToTrue() {
        let sut = makeSUT()
        #expect(sut.isAvailable == true)
    }

    @Test("FakeBiometricAuthenticator.biometryType defaults to .faceID")
    func fakeBiometryTypeDefaultsToFaceID() {
        let sut = makeSUT()
        #expect(sut.biometryType == .faceID)
    }

    @Test("FakeBiometricAuthenticator.isAvailable can be set to false")
    func fakeIsAvailableCanBeSetToFalse() {
        let sut = makeSUT()
        sut.stubbedIsAvailable = false
        #expect(sut.isAvailable == false)
    }

    @Test("FakeBiometricAuthenticator.biometryType can be set to .touchID")
    func fakeBiometryTypeCanBeSetToTouchID() {
        let sut = makeSUT()
        sut.stubbedBiometryType = .touchID
        #expect(sut.biometryType == .touchID)
    }

    // MARK: - BiometricResult enum values

    @Test("BiometricResult.success case exists")
    func biometricResultSuccessCaseExists() async {
        let sut = makeSUT()
        sut.stubbedResult = .success
        let result = await sut.authenticate(reason: "Test")
        #expect(result == .success)
    }

    @Test("BiometricResult.userCancelled case exists")
    func biometricResultUserCancelledCaseExists() async {
        let sut = makeSUT()
        sut.stubbedResult = .userCancelled
        let result = await sut.authenticate(reason: "Test")
        #expect(result == .userCancelled)
    }

    @Test("BiometricResult.systemCancelled case exists")
    func biometricResultSystemCancelledCaseExists() async {
        let sut = makeSUT()
        sut.stubbedResult = .systemCancelled
        let result = await sut.authenticate(reason: "Test")
        #expect(result == .systemCancelled)
    }

    @Test("BiometricResult.userFallback case exists")
    func biometricResultUserFallbackCaseExists() async {
        let sut = makeSUT()
        sut.stubbedResult = .userFallback
        let result = await sut.authenticate(reason: "Test")
        #expect(result == .userFallback)
    }

    @Test("BiometricResult.lockedOut case exists")
    func biometricResultLockedOutCaseExists() async {
        let sut = makeSUT()
        sut.stubbedResult = .lockedOut
        let result = await sut.authenticate(reason: "Test")
        #expect(result == .lockedOut)
    }

    @Test("BiometricResult.unavailable case exists")
    func biometricResultUnavailableCaseExists() async {
        let sut = makeSUT()
        sut.stubbedResult = .unavailable
        let result = await sut.authenticate(reason: "Test")
        #expect(result == .unavailable)
    }

    @Test("BiometricResult.failed case exists")
    func biometricResultFailedCaseExists() async {
        let sut = makeSUT()
        sut.stubbedResult = .failed
        let result = await sut.authenticate(reason: "Test")
        #expect(result == .failed)
    }

    // MARK: - BiometricResult → LockState mapping
    //
    // The contract: LockView calls authenticate(), then:
    //   .success        → calls controller.unlock()   → lockState becomes .unlocked
    //   all other cases → does NOT call controller.unlock() → lockState stays .locked
    //
    // These tests simulate that caller-side logic (without requiring LockView to exist)
    // by explicitly performing the action LockView is contractually required to take.

    @Test(".success result — caller unlocks controller → lockState is .unlocked")
    func successResultCausesUnlock() async throws {
        let controller = makeLockedController()
        let authenticator = makeSUT()
        authenticator.stubbedResult = .success

        try #require(controller.lockState == .locked,
                     "Precondition: controller must be locked before authenticate()")

        let result = await authenticator.authenticate(reason: "Unlock Christmas Tracker")
        // Contract: on .success the caller calls controller.unlock()
        if result == .success {
            controller.unlock()
        }

        #expect(controller.lockState == .unlocked,
                ".success must leave lockState .unlocked after caller calls unlock()")
    }

    @Test(".userCancelled result — caller stays locked → lockState is .locked")
    func userCancelledResultStaysLocked() async throws {
        let controller = makeLockedController()
        let authenticator = makeSUT()
        authenticator.stubbedResult = .userCancelled

        try #require(controller.lockState == .locked, "Precondition: controller must be locked")

        let result = await authenticator.authenticate(reason: "Unlock Christmas Tracker")
        // Contract: on non-.success the caller does NOT call controller.unlock()
        if result == .success {
            controller.unlock()
        }

        #expect(controller.lockState == .locked,
                ".userCancelled must leave lockState .locked — caller must not call unlock()")
    }

    @Test(".systemCancelled result — caller stays locked → lockState is .locked")
    func systemCancelledResultStaysLocked() async throws {
        let controller = makeLockedController()
        let authenticator = makeSUT()
        authenticator.stubbedResult = .systemCancelled

        try #require(controller.lockState == .locked, "Precondition: controller must be locked")

        let result = await authenticator.authenticate(reason: "Unlock Christmas Tracker")
        if result == .success { controller.unlock() }

        #expect(controller.lockState == .locked,
                ".systemCancelled must leave lockState .locked")
    }

    @Test(".userFallback result — caller stays locked → lockState is .locked")
    func userFallbackResultStaysLocked() async throws {
        let controller = makeLockedController()
        let authenticator = makeSUT()
        authenticator.stubbedResult = .userFallback

        try #require(controller.lockState == .locked, "Precondition: controller must be locked")

        let result = await authenticator.authenticate(reason: "Unlock Christmas Tracker")
        if result == .success { controller.unlock() }

        #expect(controller.lockState == .locked,
                ".userFallback must leave lockState .locked")
    }

    @Test(".lockedOut result — caller stays locked → lockState is .locked")
    func lockedOutResultStaysLocked() async throws {
        let controller = makeLockedController()
        let authenticator = makeSUT()
        authenticator.stubbedResult = .lockedOut

        try #require(controller.lockState == .locked, "Precondition: controller must be locked")

        let result = await authenticator.authenticate(reason: "Unlock Christmas Tracker")
        if result == .success { controller.unlock() }

        #expect(controller.lockState == .locked,
                ".lockedOut must leave lockState .locked")
    }

    @Test(".unavailable result — caller stays locked → lockState is .locked")
    func unavailableResultStaysLocked() async throws {
        let controller = makeLockedController()
        let authenticator = makeSUT()
        authenticator.stubbedResult = .unavailable

        try #require(controller.lockState == .locked, "Precondition: controller must be locked")

        let result = await authenticator.authenticate(reason: "Unlock Christmas Tracker")
        if result == .success { controller.unlock() }

        #expect(controller.lockState == .locked,
                ".unavailable must leave lockState .locked")
    }

    @Test(".failed result — caller stays locked → lockState is .locked")
    func failedResultStaysLocked() async throws {
        let controller = makeLockedController()
        let authenticator = makeSUT()
        authenticator.stubbedResult = .failed

        try #require(controller.lockState == .locked, "Precondition: controller must be locked")

        let result = await authenticator.authenticate(reason: "Unlock Christmas Tracker")
        if result == .success { controller.unlock() }

        #expect(controller.lockState == .locked,
                ".failed must leave lockState .locked")
    }

    // MARK: - R5: stubbedBiometryTypeName

    @Test("FakeBiometricAuthenticator.biometryTypeName reflects stubbedBiometryTypeName")
    func fakeBiometricAuthenticatorBiometryTypeNameReflectsStubbedValue() {
        let fake = makeSUT()
        fake.stubbedBiometryTypeName = "Touch ID"
        #expect(fake.biometryTypeName == "Touch ID")
    }
}
