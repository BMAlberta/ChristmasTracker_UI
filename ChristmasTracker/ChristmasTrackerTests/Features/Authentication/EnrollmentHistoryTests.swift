//
//  EnrollmentHistoryTests.swift
//  ChristmasTrackerTests
//
//  Tests for UserDefaultsEnrollmentHistory and the EnrollmentHistoryStoring protocol.
//  RED-phase: will fail to compile until:
//    - EnrollmentHistoryStoring protocol is defined
//    - UserDefaultsEnrollmentHistory struct is defined with the specified keys and behavior
//

import Testing
import Foundation
@testable import ChristmasTracker

@Suite("EnrollmentHistory Tests")
struct EnrollmentHistoryTests {

    // MARK: - Factory

    /// Returns a fresh UserDefaultsEnrollmentHistory backed by an isolated suite.
    /// Each test should call this independently so suites cannot cross-contaminate.
    private func makeSUT() -> (sut: UserDefaultsEnrollmentHistory, defaults: UserDefaults) {
        let suiteName = UUID().uuidString
        let defaults = UserDefaults(suiteName: suiteName)!
        let sut = UserDefaultsEnrollmentHistory(defaults: defaults)
        return (sut, defaults)
    }

    // MARK: - E1: previouslyEnrolledUserId nil on fresh suite

    @Test("E1: previouslyEnrolledUserId returns nil on a fresh suite")
    func e1_previouslyEnrolledUserIdIsNilOnFreshSuite() {
        let (sut, _) = makeSUT()
        #expect(sut.previouslyEnrolledUserId == nil)
    }

    // MARK: - E2: setPreviouslyEnrolledUserId stores a value

    @Test("E2: after setPreviouslyEnrolledUserId(\"u1\"), previouslyEnrolledUserId returns \"u1\"")
    func e2_setPreviouslyEnrolledUserIdStoresValue() {
        let (sut, _) = makeSUT()
        sut.setPreviouslyEnrolledUserId("u1")
        #expect(sut.previouslyEnrolledUserId == "u1")
    }

    // MARK: - E3: setPreviouslyEnrolledUserId(nil) clears the value

    @Test("E3: after setPreviouslyEnrolledUserId(nil), previouslyEnrolledUserId returns nil")
    func e3_setPreviouslyEnrolledUserIdNilClearsValue() {
        let (sut, _) = makeSUT()
        sut.setPreviouslyEnrolledUserId("u1")
        sut.setPreviouslyEnrolledUserId(nil)
        #expect(sut.previouslyEnrolledUserId == nil)
    }

    // MARK: - E4: hasSeenOffer returns false on fresh suite

    @Test("E4: hasSeenOffer(for: \"u1\") returns false on a fresh suite")
    func e4_hasSeenOfferFalseOnFreshSuite() {
        let (sut, _) = makeSUT()
        #expect(sut.hasSeenOffer(for: "u1") == false)
    }

    // MARK: - E5: markOfferShown makes hasSeenOffer return true

    @Test("E5: after markOfferShown(for: \"u1\"), hasSeenOffer(for: \"u1\") returns true")
    func e5_markOfferShownMakesHasSeenOfferTrue() {
        let (sut, _) = makeSUT()
        sut.markOfferShown(for: "u1")
        #expect(sut.hasSeenOffer(for: "u1") == true)
    }

    // MARK: - E6: marking for one user does not affect another

    @Test("E6: hasSeenOffer(for: \"u2\") is false after marking only for \"u1\"")
    func e6_markingForOneUserDoesNotAffectAnother() {
        let (sut, _) = makeSUT()
        sut.markOfferShown(for: "u1")
        #expect(sut.hasSeenOffer(for: "u2") == false)
    }

    // MARK: - E7: values survive creating a new instance backed by the same suite

    @Test("E7: values persisted through the same suite survive a new UserDefaultsEnrollmentHistory instance")
    func e7_valuesSurviveNewInstanceWithSameSuite() {
        let suiteName = UUID().uuidString
        let defaults = UserDefaults(suiteName: suiteName)!
        var sut = UserDefaultsEnrollmentHistory(defaults: defaults)
        sut.setPreviouslyEnrolledUserId("u1")
        sut.markOfferShown(for: "u1")

        // Create a second instance backed by the same suite
        let sut2 = UserDefaultsEnrollmentHistory(defaults: defaults)
        #expect(sut2.previouslyEnrolledUserId == "u1")
        #expect(sut2.hasSeenOffer(for: "u1") == true)
    }

    // MARK: - E8: different suites are independent

    @Test("E8: marking in one suite does not affect a different suite")
    func e8_differentSuitesAreIndependent() {
        let suiteName1 = UUID().uuidString
        let suiteName2 = UUID().uuidString
        let defaults1 = UserDefaults(suiteName: suiteName1)!
        let defaults2 = UserDefaults(suiteName: suiteName2)!
        var sut1 = UserDefaultsEnrollmentHistory(defaults: defaults1)
        let sut2 = UserDefaultsEnrollmentHistory(defaults: defaults2)

        sut1.setPreviouslyEnrolledUserId("u1")
        sut1.markOfferShown(for: "u1")

        #expect(sut2.previouslyEnrolledUserId == nil)
        #expect(sut2.hasSeenOffer(for: "u1") == false)
    }

    // MARK: - E9: protocol conformance (EnrollmentHistoryStoring)

    @Test("E9: UserDefaultsEnrollmentHistory conforms to EnrollmentHistoryStoring")
    func e9_conformsToEnrollmentHistoryStoring() {
        let (sut, _) = makeSUT()
        // The compile-time constraint proves conformance; use it via the protocol type.
        let _: any EnrollmentHistoryStoring = sut
    }

    // MARK: - E10: Sendable conformance

    @Test("E10: UserDefaultsEnrollmentHistory can be assigned to Sendable-constrained variable")
    func e10_sendableConformance() {
        let (sut, _) = makeSUT()
        let _: any EnrollmentHistoryStoring & Sendable = sut
    }
}
