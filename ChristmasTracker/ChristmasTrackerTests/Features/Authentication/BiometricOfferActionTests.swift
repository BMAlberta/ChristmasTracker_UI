//
//  BiometricOfferActionTests.swift
//  ChristmasTrackerTests
//
//  Tests for the pure function biometricOfferAction(...) and the BiometricOfferAction enum.
//  RED-phase: will fail to compile until:
//    - BiometricOfferAction.swift is created with the enum
//    - biometricOfferAction(...) free function is defined
//

import Testing
import Foundation
@testable import ChristmasTracker

@Suite("BiometricOfferAction Tests")
struct BiometricOfferActionTests {

    // MARK: - Table R1: readiness != .ready → .none

    @Test("R1: readiness unavailable (noHardware) → .none regardless of other inputs")
    func r1_readinessNoHardware_returnsNone() {
        let result = biometricOfferAction(
            readiness: .noHardware,
            enrolledUserId: nil,
            signedInUserId: "u1",
            previouslyEnrolledUserId: nil,
            offerShownForUser: false,
            pendingRequest: false
        )
        #expect(result == .none)
    }

    @Test("R1b: readiness needsSetup → .none regardless of other inputs")
    func r1b_readinessNeedsSetup_returnsNone() {
        let result = biometricOfferAction(
            readiness: .needsSetup(reason: .notEnrolled),
            enrolledUserId: nil,
            signedInUserId: "u1",
            previouslyEnrolledUserId: nil,
            offerShownForUser: false,
            pendingRequest: false
        )
        #expect(result == .none)
    }

    // MARK: - Table R2: same user enrolled → .silentlyReplaceToken

    @Test("R2: ready, same user enrolled → .silentlyReplaceToken")
    func r2_sameUserEnrolled_returnsSilentlyReplaceToken() {
        let result = biometricOfferAction(
            readiness: .ready,
            enrolledUserId: "u1",
            signedInUserId: "u1",
            previouslyEnrolledUserId: nil,
            offerShownForUser: false,
            pendingRequest: false
        )
        #expect(result == .silentlyReplaceToken)
    }

    // MARK: - Table R3: different user enrolled → .none

    @Test("R3: ready, different user enrolled → .none")
    func r3_differentUserEnrolled_returnsNone() {
        let result = biometricOfferAction(
            readiness: .ready,
            enrolledUserId: "u2",
            signedInUserId: "u1",
            previouslyEnrolledUserId: nil,
            offerShownForUser: false,
            pendingRequest: false
        )
        #expect(result == .none)
    }

    // MARK: - Table R4: no enrollment, pendingRequest → .showEnablementScreen

    @Test("R4: ready, no enrollment, pendingRequest true → .showEnablementScreen")
    func r4_noEnrollment_pendingRequest_returnsShowEnablementScreen() {
        let result = biometricOfferAction(
            readiness: .ready,
            enrolledUserId: nil,
            signedInUserId: "u1",
            previouslyEnrolledUserId: nil,
            offerShownForUser: false,
            pendingRequest: true
        )
        #expect(result == .showEnablementScreen)
    }

    // MARK: - Table R5: no enrollment, previouslyEnrolledUserId matches → .silentlyReenroll

    @Test("R5: ready, no enrollment, previouslyEnrolledUserId matches signed-in user → .silentlyReenroll")
    func r5_noEnrollment_previouslyEnrolledMatchesCurrent_returnsSilentlyReenroll() {
        let result = biometricOfferAction(
            readiness: .ready,
            enrolledUserId: nil,
            signedInUserId: "u1",
            previouslyEnrolledUserId: "u1",
            offerShownForUser: false,
            pendingRequest: false
        )
        #expect(result == .silentlyReenroll)
    }

    // MARK: - Table R6: no enrollment, offer not shown → .showEnablementScreen

    @Test("R6: ready, no enrollment, offerShownForUser false → .showEnablementScreen")
    func r6_noEnrollment_offerNotShown_returnsShowEnablementScreen() {
        let result = biometricOfferAction(
            readiness: .ready,
            enrolledUserId: nil,
            signedInUserId: "u1",
            previouslyEnrolledUserId: nil,
            offerShownForUser: false,
            pendingRequest: false
        )
        #expect(result == .showEnablementScreen)
    }

    // MARK: - Table R7: no enrollment, offer already shown → .none

    @Test("R7: ready, no enrollment, offerShownForUser true → .none")
    func r7_noEnrollment_offerAlreadyShown_returnsNone() {
        let result = biometricOfferAction(
            readiness: .ready,
            enrolledUserId: nil,
            signedInUserId: "u1",
            previouslyEnrolledUserId: nil,
            offerShownForUser: true,
            pendingRequest: false
        )
        #expect(result == .none)
    }

    // MARK: - Precedence: readiness wins over all

    @Test("Precedence: readiness != .ready wins over enrolledUserId == signedInUserId")
    func precedence_readinessWinsOverSameUserEnrolled() {
        let result = biometricOfferAction(
            readiness: .needsSetup(reason: .passcodeNotSet),
            enrolledUserId: "u1",
            signedInUserId: "u1",
            previouslyEnrolledUserId: "u1",
            offerShownForUser: false,
            pendingRequest: true
        )
        #expect(result == .none)
    }

    @Test("Precedence: readiness != .ready wins over all — noHardware with pending and previously enrolled")
    func precedence_noHardwareWinsOverEverything() {
        let result = biometricOfferAction(
            readiness: .noHardware,
            enrolledUserId: "u1",
            signedInUserId: "u1",
            previouslyEnrolledUserId: "u1",
            offerShownForUser: false,
            pendingRequest: true
        )
        #expect(result == .none)
    }

    // MARK: - Precedence: another user enrolled wins over pendingRequest and previouslyEnrolledUserId

    @Test("Precedence: another user enrolled wins over pendingRequest == true")
    func precedence_anotherUserEnrolledWinsOverPendingRequest() {
        let result = biometricOfferAction(
            readiness: .ready,
            enrolledUserId: "u2",
            signedInUserId: "u1",
            previouslyEnrolledUserId: nil,
            offerShownForUser: false,
            pendingRequest: true
        )
        #expect(result == .none)
    }

    @Test("Precedence: another user enrolled wins over previouslyEnrolledUserId matching signed-in user")
    func precedence_anotherUserEnrolledWinsOverPreviouslyEnrolled() {
        let result = biometricOfferAction(
            readiness: .ready,
            enrolledUserId: "u2",
            signedInUserId: "u1",
            previouslyEnrolledUserId: "u1",
            offerShownForUser: false,
            pendingRequest: false
        )
        #expect(result == .none)
    }

    // MARK: - Precedence: pendingRequest wins over previouslyEnrolledUserId and offerShownForUser

    @Test("Precedence: pendingRequest wins over previouslyEnrolledUserId matching signed-in user")
    func precedence_pendingRequestWinsOverPreviouslyEnrolled() {
        let result = biometricOfferAction(
            readiness: .ready,
            enrolledUserId: nil,
            signedInUserId: "u1",
            previouslyEnrolledUserId: "u1",
            offerShownForUser: false,
            pendingRequest: true
        )
        #expect(result == .showEnablementScreen)
    }

    @Test("Precedence: pendingRequest wins over offerShownForUser == true (offer-shown suppression overridden)")
    func precedence_pendingRequestWinsOverOfferShown() {
        let result = biometricOfferAction(
            readiness: .ready,
            enrolledUserId: nil,
            signedInUserId: "u1",
            previouslyEnrolledUserId: nil,
            offerShownForUser: true,
            pendingRequest: true
        )
        #expect(result == .showEnablementScreen)
    }

    // MARK: - Equatable conformance smoke test

    @Test("BiometricOfferAction values are Equatable")
    func equatableConformance() {
        #expect(BiometricOfferAction.none == BiometricOfferAction.none)
        #expect(BiometricOfferAction.silentlyReplaceToken == BiometricOfferAction.silentlyReplaceToken)
        #expect(BiometricOfferAction.silentlyReenroll == BiometricOfferAction.silentlyReenroll)
        #expect(BiometricOfferAction.showEnablementScreen == BiometricOfferAction.showEnablementScreen)
        #expect(BiometricOfferAction.none != BiometricOfferAction.showEnablementScreen)
    }
}
