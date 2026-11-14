//
//  ProfileBiometricToggleBannerTests.swift
//  ChristmasTrackerTests
//
//  UX1a Story U3: the biometric toggle failure moves from the Profile `.alert` to an
//  InlineErrorBanner held by ProfileBiometricToggleModel. `banner: InlineErrorBannerState?` and
//  `dismissBanner()` replace `errorMessage`. The texts are the ones the alert used. Fake data only;
//  no real Keychain (InMemoryBiometricCredentialStore).
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("ProfileBiometricToggle banner Tests")
@MainActor
struct ProfileBiometricToggleBannerTests {

    private func makeSUT(
        authenticatorResult: BiometricResult
    ) async -> (model: ProfileBiometricToggleModel, authenticator: FakeBiometricAuthenticator, service: AuthenticationService) {
        let repo = MockAuthenticationRepository()
        let sessionManager = SessionManager(initialClearables: [])
        let store = InMemoryBiometricCredentialStore()
        let authenticator = FakeBiometricAuthenticator()
        authenticator.stubbedResult = authenticatorResult
        let service = AuthenticationService(
            repository: repo,
            sessionManager: sessionManager,
            biometricAuthenticator: authenticator,
            legacyCleanup: FakeLegacyTokenCleanup(),
            credentialStore: store
        )
        await service.login(email: "u1@example.com", password: "password", rememberEmail: false)
        return (ProfileBiometricToggleModel(authService: service), authenticator, service)
    }

    @Test("no banner before anything happened")
    func initiallyNoBanner() async {
        let sut = await makeSUT(authenticatorResult: .failed)

        #expect(sut.model.banner == nil)
    }

    @Test("a rejected biometric prompt shows the authentication failure in a banner")
    func rejectedPromptShowsBanner() async throws {
        let sut = await makeSUT(authenticatorResult: .failed)

        await sut.model.toggle(to: true)

        let banner = try #require(sut.model.banner)
        #expect(banner.message == "Biometric authentication failed. Try again or use your password.")
        #expect(sut.model.isEnabled == false)
    }

    @Test("the banner can be dismissed")
    func bannerOffersDismiss() async throws {
        let sut = await makeSUT(authenticatorResult: .failed)

        await sut.model.toggle(to: true)

        let banner = try #require(sut.model.banner)
        #expect(banner.actions.contains(.dismiss))
    }

    @Test("dismissBanner clears the banner")
    func dismissClears() async {
        let sut = await makeSUT(authenticatorResult: .failed)
        await sut.model.toggle(to: true)
        #expect(sut.model.banner != nil)

        sut.model.dismissBanner()

        #expect(sut.model.banner == nil)
    }

    @Test("dismissBanner without a banner is harmless")
    func dismissWithoutBanner() async {
        let sut = await makeSUT(authenticatorResult: .success)

        sut.model.dismissBanner()

        #expect(sut.model.banner == nil)
    }

    @Test("a later successful toggle clears the earlier failure banner")
    func successClearsBanner() async {
        let sut = await makeSUT(authenticatorResult: .failed)
        await sut.model.toggle(to: true)
        #expect(sut.model.banner != nil)
        sut.authenticator.stubbedResult = .success

        await sut.model.toggle(to: true)

        #expect(sut.model.isEnabled == true)
        #expect(sut.model.banner == nil)
    }

    @Test("a second failure after a dismissal shows the banner again")
    func failureAfterDismissShowsAgain() async {
        let sut = await makeSUT(authenticatorResult: .failed)
        await sut.model.toggle(to: true)
        sut.model.dismissBanner()

        await sut.model.toggle(to: true)

        #expect(sut.model.banner != nil)
    }

    @Test("turning Face ID off shows no banner")
    func turningOffShowsNoBanner() async {
        let sut = await makeSUT(authenticatorResult: .success)
        await sut.model.toggle(to: true)

        await sut.model.toggle(to: false)

        #expect(sut.model.isEnabled == false)
        #expect(sut.model.banner == nil)
    }
}
