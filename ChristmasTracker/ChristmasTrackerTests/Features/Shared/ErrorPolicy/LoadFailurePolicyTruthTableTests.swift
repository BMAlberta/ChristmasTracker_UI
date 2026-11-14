//
//  LoadFailurePolicyTruthTableTests.swift
//  ChristmasTrackerTests
//
//  UX1a Story U1: the policy truth table for zero or one failure (cached vs not, each category).
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("LoadFailurePolicy truth table")
struct LoadFailurePolicyTruthTableTests {

    private typealias F = LoadFailureFixtures

    private func outcome(cached: Bool, _ failures: [LoadFailure]) -> LoadFailureOutcome {
        LoadFailurePolicy.outcome(hasCachedData: cached, failures: failures)
    }

    // MARK: - No failure

    @Test(arguments: [true, false])
    func noFailuresIsNone(_ cached: Bool) {
        #expect(outcome(cached: cached, []) == .none)
    }

    // MARK: - Session end and gone resource

    @Test(arguments: [true, false])
    func sessionEndedHandsOverToSignIn(_ cached: Bool) {
        #expect(outcome(cached: cached, [F.failure(.sessionEnded)]) == .signInTakesOver)
    }

    @Test(arguments: [true, false])
    func notFoundLeavesTheScreen(_ cached: Bool) {
        #expect(outcome(cached: cached, [F.failure(.notFound)]) == .leaveScreen)
    }

    // MARK: - One failure, connectivity categories

    @Test(arguments: [LoadFailureCategory.unreachable, .timeout, .server])
    func connectivityWithCacheIsStaleData(_ category: LoadFailureCategory) {
        let result = outcome(cached: true, [F.failure(category, .items)])
        #expect(result == .staleData(F.banner(LoadFailurePolicy.staleDataText, [.items])))
    }

    @Test(arguments: [LoadFailureCategory.unreachable, .timeout, .server])
    func connectivityWithoutCacheIsFullErrorWithPlainMessage(_ category: LoadFailureCategory) {
        let result = outcome(cached: false, [F.failure(category, .items)])
        #expect(result == .fullError(F.plainBanner(category, .items)))
    }

    // MARK: - One failure, plain categories (never the stale text)

    @Test(arguments: [LoadFailureCategory.rateLimited, .forbidden, .other])
    func plainCategoryWithCacheIsOneBannerWithPlainMessage(_ category: LoadFailureCategory) {
        let result = outcome(cached: true, [F.failure(category, .budgets)])
        #expect(result == .banners([F.plainBanner(category, .budgets)]))
    }

    @Test(arguments: [LoadFailureCategory.rateLimited, .forbidden, .other])
    func plainCategoryWithoutCacheIsFullError(_ category: LoadFailureCategory) {
        let result = outcome(cached: false, [F.failure(category, .budgets)])
        #expect(result == .fullError(F.plainBanner(category, .budgets)))
    }

    // MARK: - Stale text only with cached data, never for 403 or 404

    @Test(arguments: [true, false])
    func forbiddenIsNeverStaleDataOrStaleText(_ cached: Bool) {
        let result = outcome(cached: cached, [F.failure(.forbidden, .lists)])
        switch result {
        case .staleData, .merged:
            Issue.record("forbidden must never produce staleData or merged")
        case .banners(let banners):
            #expect(banners.allSatisfy { $0.message != LoadFailurePolicy.staleDataText })
        case .fullError(let banner):
            #expect(banner.message != LoadFailurePolicy.staleDataText)
        case .none, .leaveScreen, .signInTakesOver:
            Issue.record("forbidden must show a message")
        }
    }

    @Test(arguments: [true, false])
    func notFoundIsNeverStaleData(_ cached: Bool) {
        let result = outcome(cached: cached, [F.failure(.notFound, .listDetail)])
        #expect(result == .leaveScreen)
    }

    @Test(arguments: LoadFailureCategory.allCases)
    func staleTextAppearsOnlyWithCachedData(_ category: LoadFailureCategory) {
        let result = outcome(cached: false, [F.failure(category, .lists)])
        switch result {
        case .staleData, .merged:
            Issue.record("no cached data must never produce staleData or merged")
        case .banners(let banners):
            #expect(banners.allSatisfy { $0.message != LoadFailurePolicy.staleDataText })
        case .fullError(let banner):
            #expect(banner.message != LoadFailurePolicy.staleDataText)
        case .none, .leaveScreen, .signInTakesOver:
            break
        }
    }

    // MARK: - Each source is carried as the retry target

    @Test(arguments: [LoadSource.lists, .listDetail, .items, .itemDetail, .children, .stats, .budgets, .people])
    func singleFailureRetriesItsOwnSource(_ source: LoadSource) {
        let result = outcome(cached: true, [F.failure(.unreachable, source)])
        #expect(result == .staleData(F.banner(LoadFailurePolicy.staleDataText, [source])))
    }
}
