//
//  LoadFailurePolicyMergeTests.swift
//  ChristmasTrackerTests
//
//  UX1a Story U1: several failures at once (same category, mixed categories, collapse to two,
//  retry-target order and deduplication, session end and gone resource mixed in).
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("LoadFailurePolicy merging")
struct LoadFailurePolicyMergeTests {

    private typealias F = LoadFailureFixtures
    private let stale = LoadFailurePolicy.staleDataText

    private func outcome(cached: Bool, _ failures: [LoadFailure]) -> LoadFailureOutcome {
        LoadFailurePolicy.outcome(hasCachedData: cached, failures: failures)
    }

    // MARK: - Same category

    @Test(arguments: [LoadFailureCategory.unreachable, .timeout, .server])
    func sameCategorySameSourceWithCacheIsStaleDataWithOneTarget(_ category: LoadFailureCategory) {
        let result = outcome(cached: true, [F.failure(category, .items), F.failure(category, .items)])
        #expect(result == .staleData(F.banner(stale, [.items])))
    }

    @Test(arguments: [LoadFailureCategory.unreachable, .timeout, .server])
    func sameCategoryDifferentSourcesWithCacheIsMerged(_ category: LoadFailureCategory) {
        let result = outcome(cached: true, [F.failure(category, .items), F.failure(category, .listDetail)])
        #expect(result == .merged(F.banner(stale, [.items, .listDetail])))
    }

    @Test(arguments: [LoadFailureCategory.unreachable, .timeout, .server])
    func sameCategoryDifferentSourcesWithoutCacheIsFullErrorWithMergedTargets(_ category: LoadFailureCategory) {
        let result = outcome(cached: false, [F.failure(category, .items), F.failure(category, .listDetail)])
        #expect(result == .fullError(F.banner(F.defaultMessage(category, .items), [.items, .listDetail])))
    }

    @Test(arguments: [LoadFailureCategory.rateLimited, .forbidden, .other])
    func sameCategoryPlainWithCacheIsOneBannerWithMergedTargets(_ category: LoadFailureCategory) {
        let result = outcome(cached: true, [F.failure(category, .stats), F.failure(category, .budgets)])
        #expect(result == .banners([F.banner(F.defaultMessage(category, .stats), [.stats, .budgets])]))
    }

    @Test(arguments: [LoadFailureCategory.rateLimited, .forbidden, .other])
    func sameCategoryPlainSameSourceWithoutCacheIsFullErrorWithOneTarget(_ category: LoadFailureCategory) {
        let result = outcome(cached: false, [F.failure(category, .stats), F.failure(category, .stats)])
        #expect(result == .fullError(F.banner(F.defaultMessage(category, .stats), [.stats])))
    }

    @Test func groupMessageIsTheFirstFailuresPlainMessageInInputOrder() {
        let result = outcome(cached: false, [
            F.failure(.other, .children, message: "fake first"),
            F.failure(.other, .people, message: "fake second")
        ])
        #expect(result == .fullError(F.banner("fake first", [.children, .people])))
    }

    @Test func retryTargetsAreDeduplicatedInOrderOfFirstAppearance() {
        let result = outcome(cached: true, [
            F.failure(.unreachable, .items),
            F.failure(.unreachable, .lists),
            F.failure(.unreachable, .items),
            F.failure(.unreachable, .people),
            F.failure(.unreachable, .lists)
        ])
        #expect(result == .merged(F.banner(stale, [.items, .lists, .people])))
    }

    // MARK: - Different categories

    @Test func twoCategoriesWithCacheBecomeTwoBannersInPriorityOrder() {
        let result = outcome(cached: true, [F.failure(.rateLimited, .stats), F.failure(.unreachable, .lists)])
        #expect(result == .banners([
            F.banner(stale, [.lists]),
            F.plainBanner(.rateLimited, .stats)
        ]))
    }

    @Test func twoCategoriesWithoutCacheBecomeTwoBannersWithPlainMessages() {
        let result = outcome(cached: false, [F.failure(.rateLimited, .stats), F.failure(.unreachable, .lists)])
        #expect(result == .banners([
            F.plainBanner(.unreachable, .lists),
            F.plainBanner(.rateLimited, .stats)
        ]))
    }

    @Test func twoConnectivityCategoriesWithCacheBothUseTheStaleText() {
        let result = outcome(cached: true, [F.failure(.server, .items), F.failure(.timeout, .lists)])
        #expect(result == .banners([
            F.banner(stale, [.lists]),
            F.banner(stale, [.items])
        ]))
    }

    @Test(arguments: [
        [LoadFailureCategory.unreachable, .timeout, .server, .rateLimited, .forbidden, .other]
    ])
    func priorityOrderIsIndependentOfInputOrder(_ priority: [LoadFailureCategory]) {
        // Every ordered pair, fed in the reverse of its priority order, still comes out in priority order.
        for firstIndex in priority.indices {
            for secondIndex in priority.indices where secondIndex > firstIndex {
                let high = priority[firstIndex]
                let low = priority[secondIndex]
                let result = outcome(cached: false, [F.failure(low, .budgets), F.failure(high, .stats)])
                #expect(result == .banners([F.plainBanner(high, .stats), F.plainBanner(low, .budgets)]))
            }
        }
    }

    // MARK: - Collapse to two

    @Test func threeCategoriesCollapseToTwoAndAppendTargetsToTheSecond() {
        let result = outcome(cached: false, [
            F.failure(.other, .items),
            F.failure(.forbidden, .stats),
            F.failure(.server, .lists)
        ])
        // Groups by priority: server, forbidden, other. The third group's target joins the second banner.
        #expect(result == .banners([
            F.plainBanner(.server, .lists),
            F.banner(F.defaultMessage(.forbidden, .stats), [.stats, .items])
        ]))
    }

    @Test func fourCategoriesCollapseToTwoAndAppendTargetsInPriorityOrder() {
        let result = outcome(cached: true, [
            F.failure(.other, .budgets),
            F.failure(.forbidden, .stats),
            F.failure(.rateLimited, .items),
            F.failure(.unreachable, .lists)
        ])
        // Groups: unreachable, rateLimited, forbidden, other.
        #expect(result == .banners([
            F.banner(stale, [.lists]),
            F.banner(F.defaultMessage(.rateLimited, .items), [.items, .stats, .budgets])
        ]))
    }

    @Test func appendedTargetsAreDeduplicatedAgainstTheSecondBanner() {
        let result = outcome(cached: false, [
            F.failure(.unreachable, .lists),
            F.failure(.rateLimited, .items),
            F.failure(.forbidden, .items),
            F.failure(.other, .stats),
            F.failure(.other, .items)
        ])
        #expect(result == .banners([
            F.plainBanner(.unreachable, .lists),
            F.banner(F.defaultMessage(.rateLimited, .items), [.items, .stats])
        ]))
    }

    @Test func collapsedBannersNeverExceedTwo() {
        let all = LoadFailureCategory.allCases.filter {
            $0 != .notFound && $0 != .sessionEnded
        }
        let failures = all.map { F.failure($0, .lists) }
        for cached in [true, false] {
            guard case .banners(let banners) = outcome(cached: cached, failures) else {
                Issue.record("six categories must produce banners")
                continue
            }
            #expect(banners.count == 2)
            #expect(banners.allSatisfy { $0.retryTargets == [.lists] })
        }
    }

    // MARK: - Session end and gone resource win

    @Test(arguments: [true, false])
    func sessionEndedWinsOverEveryOtherFailure(_ cached: Bool) {
        let result = outcome(cached: cached, [
            F.failure(.unreachable, .lists),
            F.failure(.notFound, .listDetail),
            F.failure(.sessionEnded, .items),
            F.failure(.other, .stats)
        ])
        #expect(result == .signInTakesOver)
    }

    @Test(arguments: [true, false])
    func notFoundWinsOverRemainingFailures(_ cached: Bool) {
        let result = outcome(cached: cached, [
            F.failure(.unreachable, .lists),
            F.failure(.server, .items),
            F.failure(.notFound, .listDetail),
            F.failure(.rateLimited, .stats)
        ])
        #expect(result == .leaveScreen)
    }

    @Test(arguments: [LoadFailureCategory.unreachable, .timeout, .server, .rateLimited, .forbidden, .other])
    func notFoundWithAnyOtherCategoryLeavesTheScreen(_ other: LoadFailureCategory) {
        for cached in [true, false] {
            #expect(outcome(cached: cached, [F.failure(other, .items), F.failure(.notFound, .listDetail)]) == .leaveScreen)
        }
    }

    @Test(arguments: [LoadFailureCategory.unreachable, .timeout, .server, .rateLimited, .forbidden, .other, .notFound])
    func sessionEndedWithAnyOtherCategorySignsIn(_ other: LoadFailureCategory) {
        for cached in [true, false] {
            #expect(outcome(cached: cached, [F.failure(other, .items), F.failure(.sessionEnded, .lists)]) == .signInTakesOver)
        }
    }
}
