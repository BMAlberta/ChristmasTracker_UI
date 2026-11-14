//
//  LoadFailureClassificationTests.swift
//  ChristmasTrackerTests
//
//  UX1a Story U1: every case of ListError, ItemError, ChildError and BudgetError is classified.
//  The expected category comes from an exhaustive switch in LoadFailureFixtures (no default), so a
//  new error case fails to compile until it is given a deliberate category.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("LoadFailure classification")
struct LoadFailureClassificationTests {

    private typealias F = LoadFailureFixtures

    // MARK: - ListError

    @Test(arguments: LoadFailureFixtures.allListErrors)
    func listErrorCategory(_ error: ListError) {
        let failure = LoadFailure(error, source: .lists)
        #expect(failure.category == F.expectedCategory(error))
    }

    @Test(arguments: LoadFailureFixtures.allListErrors)
    func listErrorCopiesMessageAndSource(_ error: ListError) {
        let failure = LoadFailure(error, source: .listDetail)
        #expect(failure.plainMessage == error.userMessage)
        #expect(failure.source == .listDetail)
    }

    // MARK: - ItemError

    @Test(arguments: LoadFailureFixtures.allItemErrors)
    func itemErrorCategory(_ error: ItemError) {
        let failure = LoadFailure(error, source: .items)
        #expect(failure.category == F.expectedCategory(error))
    }

    @Test(arguments: LoadFailureFixtures.allItemErrors)
    func itemErrorCopiesMessageAndSource(_ error: ItemError) {
        let failure = LoadFailure(error, source: .itemDetail)
        #expect(failure.plainMessage == error.userMessage)
        #expect(failure.source == .itemDetail)
    }

    // MARK: - ChildError

    @Test(arguments: LoadFailureFixtures.allChildErrors)
    func childErrorCategory(_ error: ChildError) {
        let failure = LoadFailure(error, source: .children)
        #expect(failure.category == F.expectedCategory(error))
    }

    @Test(arguments: LoadFailureFixtures.allChildErrors)
    func childErrorCopiesMessageAndSource(_ error: ChildError) {
        let failure = LoadFailure(error, source: .people)
        #expect(failure.plainMessage == error.userMessage)
        #expect(failure.source == .people)
    }

    // MARK: - BudgetError

    @Test(arguments: LoadFailureFixtures.allBudgetErrors)
    func budgetErrorCategory(_ error: BudgetError) {
        let failure = LoadFailure(error, source: .budgets)
        #expect(failure.category == F.expectedCategory(error))
    }

    @Test(arguments: LoadFailureFixtures.allBudgetErrors)
    func budgetErrorCopiesMessageAndSource(_ error: BudgetError) {
        let failure = LoadFailure(error, source: .stats)
        #expect(failure.plainMessage == error.userMessage)
        #expect(failure.source == .stats)
    }

    // MARK: - Spot checks of the documented mapping

    @Test func documentedMappingSpotChecks() {
        #expect(LoadFailure(ListError.network, source: .lists).category == .unreachable)
        #expect(LoadFailure(ListError.invalidResponse, source: .lists).category == .server)
        #expect(LoadFailure(ListError.unauthorized, source: .lists).category == .sessionEnded)
        #expect(LoadFailure(ChildError.childNotFound, source: .children).category == .notFound)
        #expect(LoadFailure(ChildError.childHasLists, source: .children).category == .other)
        #expect(LoadFailure(ItemError.invalidPrice, source: .items).category == .other)
        #expect(LoadFailure(BudgetError.hasPurchases(message: "fake"), source: .budgets).category == .other)
    }

    @Test func noTypedErrorClassifiesAsTimeout() {
        let categories =
            F.allListErrors.map { LoadFailure($0, source: .lists).category }
            + F.allItemErrors.map { LoadFailure($0, source: .items).category }
            + F.allChildErrors.map { LoadFailure($0, source: .children).category }
            + F.allBudgetErrors.map { LoadFailure($0, source: .budgets).category }
        #expect(!categories.contains(.timeout))
    }

    // MARK: - retryAfter

    @Test func nonRateLimitedErrorsHaveNoRetryAfter() {
        for error in F.allListErrors {
            if case .rateLimited = error { continue }
            #expect(LoadFailure(error, source: .lists).retryAfter == nil)
        }
        for error in F.allItemErrors {
            if case .rateLimited = error { continue }
            #expect(LoadFailure(error, source: .items).retryAfter == nil)
        }
        for error in F.allChildErrors {
            if case .rateLimited = error { continue }
            #expect(LoadFailure(error, source: .children).retryAfter == nil)
        }
        for error in F.allBudgetErrors {
            if case .rateLimited = error { continue }
            #expect(LoadFailure(error, source: .budgets).retryAfter == nil)
        }
    }

    @Test(arguments: [
        (1.0, 1), (1.2, 2), (30.0, 30), (59.999, 60), (3600.0, 3600), (3600.5, 3600), (5000.0, 3600)
    ] as [(TimeInterval, Int)])
    func rateLimitedRetryAfterRoundsUpAndCaps(_ seconds: TimeInterval, _ expected: Int) {
        #expect(LoadFailure(ListError.rateLimited(retryAfter: seconds), source: .lists).retryAfter == expected)
        #expect(LoadFailure(ItemError.rateLimited(retryAfter: seconds), source: .items).retryAfter == expected)
        #expect(LoadFailure(ChildError.rateLimited(retryAfter: seconds), source: .children).retryAfter == expected)
        #expect(LoadFailure(BudgetError.rateLimited(retryAfter: seconds), source: .budgets).retryAfter == expected)
    }

    @Test(arguments: [0.0, 0.5, 0.999, -3.0, TimeInterval.infinity, -TimeInterval.infinity, TimeInterval.nan])
    func rateLimitedRetryAfterIsNilWhenNotUsable(_ seconds: TimeInterval) {
        #expect(LoadFailure(ListError.rateLimited(retryAfter: seconds), source: .lists).retryAfter == nil)
        #expect(LoadFailure(ItemError.rateLimited(retryAfter: seconds), source: .items).retryAfter == nil)
        #expect(LoadFailure(ChildError.rateLimited(retryAfter: seconds), source: .children).retryAfter == nil)
        #expect(LoadFailure(BudgetError.rateLimited(retryAfter: seconds), source: .budgets).retryAfter == nil)
    }

    @Test func rateLimitedStillClassifiesAsRateLimitedWhenRetryAfterIsUnusable() {
        #expect(LoadFailure(ListError.rateLimited(retryAfter: .nan), source: .lists).category == .rateLimited)
    }

    // MARK: - Memberwise init

    @Test func memberwiseInitDefaultsRetryAfterToNil() {
        let failure = LoadFailure(category: .timeout, source: .stats, plainMessage: "fake")
        #expect(failure.retryAfter == nil)
        #expect(failure.category == .timeout)
        #expect(failure.source == .stats)
        #expect(failure.plainMessage == "fake")
    }

    @Test func categoryHasExactlyTheEightDocumentedCases() {
        #expect(Set(LoadFailureCategory.allCases) == [
            .unreachable, .timeout, .server, .rateLimited, .forbidden, .notFound, .sessionEnded, .other
        ])
        #expect(LoadFailureCategory.allCases.count == 8)
    }
}
