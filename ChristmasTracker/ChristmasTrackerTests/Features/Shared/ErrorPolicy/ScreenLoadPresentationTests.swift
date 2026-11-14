//
//  ScreenLoadPresentationTests.swift
//  ChristmasTrackerTests
//
//  UX1a Story U3: ScreenLoadPresentation.make maps every LoadFailurePolicy outcome to what a screen
//  renders: none (everything empty), staleData and merged (one banner), banners (up to two),
//  fullError, leaveScreen and signInTakesOver. Cached data never yields a full error; no cached data
//  never yields the stale-data text. Fake data only.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("ScreenLoadPresentation Tests")
struct ScreenLoadPresentationTests {

    private typealias F = LoadFailureFixtures

    // Local copies: the fixture statics are main-actor isolated and @Test arguments are not.
    nonisolated static let connectivity: [LoadFailureCategory] = [.unreachable, .timeout, .server]
    nonisolated static let plainCategories: [LoadFailureCategory] = [.rateLimited, .forbidden, .other]

    private func makeSUT(hasCachedData: Bool, failures: [LoadFailure]) -> ScreenLoadPresentation {
        ScreenLoadPresentation.make(hasCachedData: hasCachedData, failures: failures)
    }

    private func expectEmpty(_ sut: ScreenLoadPresentation, _ note: String = "") {
        #expect(sut.banners.isEmpty, "banners: \(note)")
        #expect(sut.fullError == nil, "fullError: \(note)")
        #expect(sut.leavesScreen == false, "leavesScreen: \(note)")
        #expect(sut.signInTakesOver == false, "signInTakesOver: \(note)")
    }

    // MARK: none

    @Test("no failures: everything is empty, with or without cached data", arguments: [false, true])
    func noneIsEmpty(hasCachedData: Bool) {
        expectEmpty(makeSUT(hasCachedData: hasCachedData, failures: []))
    }

    // MARK: staleData

    @Test("cached data and one connectivity failure: one stale-data banner for its source",
          arguments: ScreenLoadPresentationTests.connectivity)
    func staleData(category: LoadFailureCategory) {
        let sut = makeSUT(hasCachedData: true, failures: [F.failure(category, .listDetail)])

        #expect(sut.banners == [F.banner(LoadFailurePolicy.staleDataText, [.listDetail])])
        #expect(sut.fullError == nil)
        #expect(sut.leavesScreen == false)
        #expect(sut.signInTakesOver == false)
    }

    // MARK: merged

    @Test("cached data and the same connectivity category from two sources: ONE banner that retries both",
          arguments: ScreenLoadPresentationTests.connectivity)
    func merged(category: LoadFailureCategory) {
        let sut = makeSUT(
            hasCachedData: true,
            failures: [F.failure(category, .listDetail), F.failure(category, .items)]
        )

        #expect(sut.banners == [F.banner(LoadFailurePolicy.staleDataText, [.listDetail, .items])])
        #expect(sut.fullError == nil)
    }

    @Test("two failures of the same source are one banner with that source once")
    func mergedSameSourceDeduplicates() {
        let sut = makeSUT(
            hasCachedData: true,
            failures: [F.failure(.unreachable, .listDetail), F.failure(.unreachable, .listDetail)]
        )

        #expect(sut.banners == [F.banner(LoadFailurePolicy.staleDataText, [.listDetail])])
    }

    // MARK: banners

    @Test("cached data and a non-connectivity failure: one banner with the plain message, never the stale text",
          arguments: ScreenLoadPresentationTests.plainCategories)
    func cachedPlainCategory(category: LoadFailureCategory) {
        let sut = makeSUT(hasCachedData: true, failures: [F.failure(category, .lists)])

        #expect(sut.banners == [F.plainBanner(category, .lists)])
        #expect(sut.fullError == nil)
        #expect(sut.banners.allSatisfy { $0.message != LoadFailurePolicy.staleDataText })
    }

    @Test("two different categories: two banners in priority order", arguments: [false, true])
    func twoCategoriesTwoBanners(hasCachedData: Bool) {
        let sut = makeSUT(
            hasCachedData: hasCachedData,
            failures: [F.failure(.server, .items), F.failure(.unreachable, .listDetail)]
        )

        #expect(sut.banners.count == 2)
        #expect(sut.banners.map(\.retryTargets) == [[.listDetail], [.items]], "unreachable comes before server")
        #expect(sut.fullError == nil, "two banners are never a full error")
    }

    @Test("more than two categories collapse to two banners that still retry every failed source")
    func threeCategoriesCollapse() {
        let sut = makeSUT(
            hasCachedData: true,
            failures: [
                F.failure(.unreachable, .listDetail),
                F.failure(.server, .items),
                F.failure(.rateLimited, .lists)
            ]
        )

        #expect(sut.banners.count == 2)
        let targets = Set(sut.banners.flatMap(\.retryTargets))
        #expect(targets == [.listDetail, .items, .lists])
    }

    // MARK: fullError

    @Test("no cached data and one failure: the full error with the plain message and its retry target",
          arguments: LoadFailureCategory.allCases.filter { $0 != .notFound && $0 != .sessionEnded })
    func fullError(category: LoadFailureCategory) {
        let sut = makeSUT(hasCachedData: false, failures: [F.failure(category, .children)])

        #expect(sut.fullError == F.plainBanner(category, .children))
        #expect(sut.banners.isEmpty, "the full error is not also a banner")
        #expect(sut.leavesScreen == false)
        #expect(sut.signInTakesOver == false)
    }

    @Test("no cached data and the same category from two sources: one full error that retries both")
    func fullErrorMergesTargets() {
        let sut = makeSUT(
            hasCachedData: false,
            failures: [F.failure(.unreachable, .listDetail), F.failure(.unreachable, .items)]
        )

        #expect(sut.fullError?.retryTargets == [.listDetail, .items])
        #expect(sut.banners.isEmpty)
    }

    // MARK: leaveScreen

    @Test("a gone resource leaves the screen and shows no banner", arguments: [false, true])
    func leavesScreen(hasCachedData: Bool) {
        let sut = makeSUT(hasCachedData: hasCachedData, failures: [F.failure(.notFound, .listDetail)])

        #expect(sut.leavesScreen == true)
        #expect(sut.banners.isEmpty)
        #expect(sut.fullError == nil)
        #expect(sut.signInTakesOver == false)
    }

    @Test("a gone resource wins over a connectivity failure of another source")
    func goneBeatsConnectivity() {
        let sut = makeSUT(
            hasCachedData: true,
            failures: [F.failure(.unreachable, .items), F.failure(.notFound, .listDetail)]
        )

        #expect(sut.leavesScreen == true)
        #expect(sut.banners.isEmpty)
    }

    // MARK: signInTakesOver

    @Test("a session end hands over to the sign-in flow and shows nothing", arguments: [false, true])
    func signInTakesOver(hasCachedData: Bool) {
        let sut = makeSUT(hasCachedData: hasCachedData, failures: [F.failure(.sessionEnded, .lists)])

        #expect(sut.signInTakesOver == true)
        #expect(sut.banners.isEmpty)
        #expect(sut.fullError == nil)
        #expect(sut.leavesScreen == false)
    }

    @Test("a session end wins over a gone resource and over connectivity failures")
    func sessionEndBeatsEverything() {
        let sut = makeSUT(
            hasCachedData: true,
            failures: [
                F.failure(.notFound, .listDetail),
                F.failure(.unreachable, .items),
                F.failure(.sessionEnded, .lists)
            ]
        )

        #expect(sut.signInTakesOver == true)
        #expect(sut.leavesScreen == false)
        #expect(sut.banners.isEmpty)
    }

    // MARK: Invariants over every category

    @Test("cached data never yields a full error", arguments: LoadFailureCategory.allCases)
    func cachedNeverFullError(category: LoadFailureCategory) {
        let single = makeSUT(hasCachedData: true, failures: [F.failure(category, .stats)])
        let pair = makeSUT(hasCachedData: true, failures: [F.failure(category, .stats), F.failure(category, .budgets)])

        #expect(single.fullError == nil)
        #expect(pair.fullError == nil)
    }

    @Test("no cached data never yields the stale-data text", arguments: LoadFailureCategory.allCases)
    func uncachedNeverStale(category: LoadFailureCategory) {
        let sut = makeSUT(hasCachedData: false, failures: [F.failure(category, .stats), F.failure(.server, .budgets)])
        let texts = sut.banners.map(\.message) + [sut.fullError?.message].compactMap { $0 }

        #expect(!texts.contains(LoadFailurePolicy.staleDataText))
    }

    @Test("forbidden never shows the stale-data text", arguments: [false, true])
    func forbiddenNeverStale(hasCachedData: Bool) {
        let sut = makeSUT(hasCachedData: hasCachedData, failures: [F.failure(.forbidden, .listDetail)])
        let texts = sut.banners.map(\.message) + [sut.fullError?.message].compactMap { $0 }

        #expect(texts == [F.defaultMessage(.forbidden, .listDetail)])
    }

    @Test("the rate-limit message keeps its retry hint through the presentation", arguments: [false, true])
    func rateLimitHintSurvives(hasCachedData: Bool) {
        let failure = LoadFailure(ListError.rateLimited(retryAfter: 30), source: .lists)
        let sut = makeSUT(hasCachedData: hasCachedData, failures: [failure])
        let texts = sut.banners.map(\.message) + [sut.fullError?.message].compactMap { $0 }

        #expect(texts == [ListError.rateLimited(retryAfter: 30).userMessage])
        #expect(texts.first?.contains("30 seconds") == true)
    }

    // MARK: Agreement with the policy, over the whole truth table

    private func expectedPresentation(_ outcome: LoadFailureOutcome) -> (
        banners: [LoadBanner], fullError: LoadBanner?, leaves: Bool, signIn: Bool
    ) {
        switch outcome {
        case .none: return ([], nil, false, false)
        case .staleData(let banner), .merged(let banner): return ([banner], nil, false, false)
        case .banners(let banners): return (banners, nil, false, false)
        case .fullError(let banner): return ([], banner, false, false)
        case .leaveScreen: return ([], nil, true, false)
        case .signInTakesOver: return ([], nil, false, true)
        }
    }

    @Test("the presentation is exactly the policy outcome for every pair of categories",
          arguments: LoadFailureCategory.allCases, LoadFailureCategory.allCases)
    func agreesWithPolicy(first: LoadFailureCategory, second: LoadFailureCategory) {
        let failures = [F.failure(first, .listDetail), F.failure(second, .items)]
        for hasCachedData in [false, true] {
            let outcome = LoadFailurePolicy.outcome(hasCachedData: hasCachedData, failures: failures)
            let expected = expectedPresentation(outcome)

            let sut = makeSUT(hasCachedData: hasCachedData, failures: failures)

            #expect(sut.banners == expected.banners, "\(first) + \(second), cached=\(hasCachedData)")
            #expect(sut.fullError == expected.fullError, "\(first) + \(second), cached=\(hasCachedData)")
            #expect(sut.leavesScreen == expected.leaves, "\(first) + \(second), cached=\(hasCachedData)")
            #expect(sut.signInTakesOver == expected.signIn, "\(first) + \(second), cached=\(hasCachedData)")
        }
    }

    @Test("a single failure of every category agrees with the policy", arguments: LoadFailureCategory.allCases, [false, true])
    func singleAgreesWithPolicy(category: LoadFailureCategory, hasCachedData: Bool) {
        let failures = [F.failure(category, .lists)]
        let expected = expectedPresentation(LoadFailurePolicy.outcome(hasCachedData: hasCachedData, failures: failures))

        let sut = makeSUT(hasCachedData: hasCachedData, failures: failures)

        #expect(sut.banners == expected.banners)
        #expect(sut.fullError == expected.fullError)
        #expect(sut.leavesScreen == expected.leaves)
        #expect(sut.signInTakesOver == expected.signIn)
    }
}
