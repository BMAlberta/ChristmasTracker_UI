//
//  LoadFailureTextTests.swift
//  ChristmasTrackerTests
//
//  UX1a Story U1: the message texts the policy puts in banners.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("LoadFailurePolicy texts")
struct LoadFailureTextTests {

    private func outcome(cached: Bool, _ failures: [LoadFailure]) -> LoadFailureOutcome {
        LoadFailurePolicy.outcome(hasCachedData: cached, failures: failures)
    }

    @Test func staleDataTextIsExact() {
        #expect(LoadFailurePolicy.staleDataText == "Couldn't update. Showing saved data.")
    }

    @Test func networkFailureWithCacheShowsStaleTextNotTheNetworkMessage() throws {
        let failure = LoadFailure(ListError.network, source: .lists)
        let result = outcome(cached: true, [failure])
        #expect(result == .staleData(LoadBanner(message: "Couldn't update. Showing saved data.", retryTargets: [.lists])))
        #expect(failure.plainMessage == ListError.network.userMessage)
    }

    @Test func networkFailureWithoutCacheShowsTheTypedErrorMessage() {
        let result = outcome(cached: false, [LoadFailure(ListError.network, source: .lists)])
        #expect(result == .fullError(LoadBanner(message: ListError.network.userMessage, retryTargets: [.lists])))
    }

    @Test func serverFailureWithoutCacheShowsTheTypedErrorMessage() {
        let result = outcome(cached: false, [LoadFailure(ItemError.server, source: .items)])
        #expect(result == .fullError(LoadBanner(message: ItemError.server.userMessage, retryTargets: [.items])))
    }

    @Test func rateLimitMessageKeepsItsRetryHintWithCache() {
        let error = ListError.rateLimited(retryAfter: 30)
        let result = outcome(cached: true, [LoadFailure(error, source: .lists)])
        #expect(error.userMessage == "Too many requests. Please try again in 30 seconds.")
        #expect(result == .banners([LoadBanner(message: error.userMessage, retryTargets: [.lists])]))
    }

    @Test func rateLimitMessageKeepsItsRetryHintWithoutCache() {
        let error = ListError.rateLimited(retryAfter: 30)
        let result = outcome(cached: false, [LoadFailure(error, source: .lists)])
        #expect(result == .fullError(LoadBanner(message: error.userMessage, retryTargets: [.lists])))
    }

    @Test func forbiddenShowsThePermissionMessageNeverTheStaleText() {
        for cached in [true, false] {
            let failure = LoadFailure(ListError.forbidden, source: .listDetail)
            let result = outcome(cached: cached, [failure])
            let banner = LoadBanner(message: "You don't have permission to do that.", retryTargets: [.listDetail])
            #expect(result == (cached ? .banners([banner]) : .fullError(banner)))
        }
    }

    @Test func validationKeepsTheServerMessage() {
        let failure = LoadFailure(ListError.validation(message: "fake server text"), source: .people)
        #expect(failure.plainMessage == "fake server text")
        #expect(outcome(cached: true, [failure]) == .banners([LoadBanner(message: "fake server text", retryTargets: [.people])]))
    }

    @Test func bannerCarriesMessageAndTargetsAndIsEquatable() {
        let one = LoadBanner(message: "fake", retryTargets: [.lists, .items])
        #expect(one == LoadBanner(message: "fake", retryTargets: [.lists, .items]))
        #expect(one != LoadBanner(message: "fake", retryTargets: [.items, .lists]))
        #expect(one != LoadBanner(message: "other", retryTargets: [.lists, .items]))
    }
}
