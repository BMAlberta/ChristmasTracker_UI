//
//  ProfileBiometricToggleModelTests.swift
//  ChristmasTrackerTests
//
//  Tests for Story R10 (C2a): ProfileBiometricToggleModel
//
//  Contract (from Gate 1 spec, R10):
//
//    @MainActor @Observable final class ProfileBiometricToggleModel {
//        var isEnabled: Bool
//        init(preference: any BiometricUnlockPreferring, enablementModel: BiometricEnablementModel)
//        func toggle(to newValue: Bool) async
//    }
//
//    toggle(to: true)  — runs BiometricEnablementModel.enable(); sets isEnabled = true
//                        only if state == .succeeded; otherwise sets isEnabled = false.
//    toggle(to: false) — immediately sets isEnabled = false and
//                        preference.biometricUnlockEnabled = false; does NOT call enable().
//
//  RED-phase: will fail to compile until ProfileBiometricToggleModel is added to the
//  production module ("cannot find type 'ProfileBiometricToggleModel' in scope").
//
//  Concurrency: suite is @MainActor because ProfileBiometricToggleModel is @MainActor
//  and BiometricEnablementModel is @MainActor.
//
//  FakeBiometricUnlockPreference is defined in BiometricUnlockPreferenceTests.swift
//  and is in scope within this test target.
//
//  FakeBiometricAuthenticator lives in the production module and is accessible here.
//

import Testing
@testable import ChristmasTracker

// MARK: - Suite

@Suite("ProfileBiometricToggleModel Tests")
@MainActor
struct ProfileBiometricToggleModelTests {

    // MARK: - Factory

    /// Returns a fresh SUT plus its injected collaborators.
    /// `result` controls the BiometricResult that FakeBiometricAuthenticator returns
    /// when BiometricEnablementModel.enable() is called.
    private func makeSUT(
        result: BiometricResult = .success,
        preferenceEnabled: Bool = false
    ) -> (sut: ProfileBiometricToggleModel,
          pref: FakeBiometricUnlockPreference,
          enablementModel: BiometricEnablementModel) {
        let auth = FakeBiometricAuthenticator()
        auth.stubbedResult = result
        let pref = FakeBiometricUnlockPreference()
        pref.biometricUnlockEnabled = preferenceEnabled
        let enablementModel = BiometricEnablementModel(authenticator: auth, preference: pref)
        let sut = ProfileBiometricToggleModel(preference: pref, enablementModel: enablementModel)
        return (sut, pref, enablementModel)
    }

    // MARK: - Tests

    // R10-C2a-1: toggle(to: true) with biometrics succeeding → isEnabled true, preference true
    @Test("toggleOnSucceedsWhenBiometricsSucceed")
    func toggleOnSucceedsWhenBiometricsSucceed() async {
        let (sut, pref, _) = makeSUT(result: .success)
        await sut.toggle(to: true)
        #expect(sut.isEnabled == true,
                "isEnabled must be true after toggle(to: true) when biometrics succeed")
        #expect(pref.biometricUnlockEnabled == true,
                "preference.biometricUnlockEnabled must be true after a successful toggle on")
    }

    // R10-C2a-2: toggle(to: true) with biometrics failing → isEnabled false, preference unchanged
    @Test("toggleOnFailsWhenBiometricsFail")
    func toggleOnFailsWhenBiometricsFail() async {
        let (sut, pref, _) = makeSUT(result: .failed)
        await sut.toggle(to: true)
        #expect(sut.isEnabled == false,
                "isEnabled must remain false when enable() results in .failed")
        #expect(pref.biometricUnlockEnabled == false,
                "preference.biometricUnlockEnabled must remain false when enable() fails")
    }

    // R10-C2a-3: toggle(to: true) with cancellation → isEnabled false
    @Test("toggleOnFailsWhenBiometricsCancelled")
    func toggleOnFailsWhenBiometricsCancelled() async {
        // userCancelled maps to BiometricEnablementModel.state == .idle (not .succeeded)
        let (sut, _, _) = makeSUT(result: .userCancelled)
        await sut.toggle(to: true)
        #expect(sut.isEnabled == false,
                "isEnabled must be false when the user cancels the biometric prompt")
    }

    // R10-C2a-4: toggle(to: false) sets isEnabled = false and preference = false immediately
    @Test("toggleOffSetsIsEnabledFalseImmediately")
    func toggleOffSetsIsEnabledFalseImmediately() async {
        // Start with an enabled state
        let (sut, pref, _) = makeSUT(result: .success, preferenceEnabled: true)
        // Precondition: set up as if previously enabled
        await sut.toggle(to: true)
        #expect(sut.isEnabled == true, "Precondition: isEnabled should be true before toggling off")
        await sut.toggle(to: false)
        #expect(sut.isEnabled == false,
                "isEnabled must be false after toggle(to: false)")
        #expect(pref.biometricUnlockEnabled == false,
                "preference.biometricUnlockEnabled must be false after toggle(to: false)")
    }

    // R10-C2a-5: toggle(to: false) does not call enable()
    // Verified by: after toggle(to: false), enablementModel.state remains .idle (enable was never called)
    @Test("toggleOffDoesNotCallEnablementModel")
    func toggleOffDoesNotCallEnablementModel() async {
        let (sut, _, enablementModel) = makeSUT(result: .success)
        // State before: idle
        #expect(enablementModel.state == .idle, "Precondition: state must be .idle")
        await sut.toggle(to: false)
        // If enable() had been called with .success, state would be .succeeded — it must remain .idle
        #expect(enablementModel.state == .idle,
                "toggle(to: false) must not call enable(); enablementModel.state must remain .idle")
    }

    // R10-C2a-6: initial isEnabled reflects preference.biometricUnlockEnabled = true
    @Test("initialIsEnabledReflectsPreference")
    func initialIsEnabledReflectsPreference() {
        let (sut, _, _) = makeSUT(result: .success, preferenceEnabled: true)
        #expect(sut.isEnabled == true,
                "isEnabled must be true on init when preference.biometricUnlockEnabled is true")
    }

    // R10-C2a-7: initial isEnabled is false when preference is false
    @Test("initialIsEnabledFalseWhenPreferenceFalse")
    func initialIsEnabledFalseWhenPreferenceFalse() {
        let (sut, _, _) = makeSUT(result: .success, preferenceEnabled: false)
        #expect(sut.isEnabled == false,
                "isEnabled must be false on init when preference.biometricUnlockEnabled is false")
    }

    // R10-C2a-8: preference.biometricUnlockEnabled is not set to true until after enable() succeeds;
    // if enable() fails, preference remains unchanged.
    @Test("toggleOnSetsPreferenceOnlyAfterSuccess")
    func toggleOnSetsPreferenceOnlyAfterSuccess() async {
        // Case A: success path — preference is set to true
        let (sutA, prefA, _) = makeSUT(result: .success, preferenceEnabled: false)
        await sutA.toggle(to: true)
        #expect(prefA.biometricUnlockEnabled == true,
                "preference.biometricUnlockEnabled must be true after a successful enable()")

        // Case B: failure path — preference is NOT set to true
        let (sutB, prefB, _) = makeSUT(result: .lockedOut, preferenceEnabled: false)
        await sutB.toggle(to: true)
        #expect(prefB.biometricUnlockEnabled == false,
                "preference.biometricUnlockEnabled must remain false when enable() fails (lockedOut)")
    }
}
