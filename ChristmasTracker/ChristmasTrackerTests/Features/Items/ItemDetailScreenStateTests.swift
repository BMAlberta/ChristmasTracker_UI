//
//  ItemDetailScreenStateTests.swift
//  ChristmasTrackerTests
//
//  Fix pass F1: the item detail screen can no longer spin forever. `ItemDetailScreenState.resolve`
//  decides what the screen shows. The rule, in this order:
//   1. an item is present                                  -> .loaded(item)
//   2. else isLoading, or the load has not started yet      -> .loading (the only spinner)
//   3. else a displayable error                             -> .error(banner with a Try Again action)
//   4. else (no error, or .sessionEnded)                    -> .notLoaded
//
//  Pure value logic: no service, no view. The whole truth table is covered.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("ItemDetailScreenState")
struct ItemDetailScreenStateTests {

    private let sampleItem = ItemFixtures.item(id: "item-1", listId: "list-1", name: "Fake Gift")

    // MARK: Truth table

    enum ErrorInput: CaseIterable, Sendable, CustomTestStringConvertible {
        case none, retryable, nonRetryable, notFound, sessionEnded

        var error: ItemError? {
            switch self {
            case .none: nil
            case .retryable: .network
            case .nonRetryable: .forbidden
            case .notFound: .notFound
            case .sessionEnded: .sessionEnded
            }
        }

        var testDescription: String {
            switch self {
            case .none: "no error"
            case .retryable: "network error"
            case .nonRetryable: "forbidden error"
            case .notFound: "notFound error"
            case .sessionEnded: "sessionEnded"
            }
        }
    }

    struct Row: Sendable, CustomTestStringConvertible {
        let hasItem: Bool
        let isLoading: Bool
        let hasStartedLoading: Bool
        let error: ErrorInput

        var testDescription: String {
            "item=\(hasItem) loading=\(isLoading) started=\(hasStartedLoading) error=\(error.testDescription)"
        }
    }

    static let allRows: [Row] = {
        var rows: [Row] = []
        for hasItem in [false, true] {
            for isLoading in [false, true] {
                for started in [false, true] {
                    for error in ErrorInput.allCases {
                        rows.append(Row(hasItem: hasItem, isLoading: isLoading, hasStartedLoading: started, error: error))
                    }
                }
            }
        }
        return rows
    }()

    @Test("every combination of item, isLoading, hasStartedLoading and error resolves per the rule", arguments: allRows)
    func truthTable(row: Row) throws {
        let item: ListItem? = row.hasItem ? sampleItem : nil

        let state = ItemDetailScreenState.resolve(
            item: item, isLoading: row.isLoading, hasStartedLoading: row.hasStartedLoading, error: row.error.error
        )

        if row.hasItem {
            #expect(state == .loaded(sampleItem), "an item always wins: \(row.testDescription)")
        } else if row.isLoading || !row.hasStartedLoading {
            #expect(state == .loading, "\(row.testDescription)")
        } else if let error = row.error.error, error != .sessionEnded {
            let banner = try #require(ItemErrorPresentation.banner(for: error, hasRetryAction: true))
            #expect(state == .error(banner), "\(row.testDescription)")
        } else {
            #expect(state == .notLoaded, "\(row.testDescription)")
        }
    }

    // MARK: Named cases

    @Test("an item present is loaded whatever the flags and error are")
    func itemPresentIsLoaded() {
        for isLoading in [false, true] {
            for started in [false, true] {
                for error in [nil, ItemError.network, .sessionEnded] as [ItemError?] {
                    let state = ItemDetailScreenState.resolve(
                        item: sampleItem, isLoading: isLoading, hasStartedLoading: started, error: error
                    )
                    #expect(state == .loaded(sampleItem))
                }
            }
        }
    }

    @Test("the spinner shows while loading with no item, with or without an error")
    func spinnerWhileLoading() {
        for error in [nil, ItemError.network, .sessionEnded] as [ItemError?] {
            #expect(ItemDetailScreenState.resolve(item: nil, isLoading: true, hasStartedLoading: true, error: error) == .loading)
        }
    }

    @Test("the spinner shows before the load has started, so the first frame does not flash an error")
    func spinnerBeforeStart() {
        #expect(ItemDetailScreenState.resolve(item: nil, isLoading: false, hasStartedLoading: false, error: nil) == .loading)
        #expect(ItemDetailScreenState.resolve(item: nil, isLoading: false, hasStartedLoading: false, error: .network) == .loading)
    }

    @Test("never a spinner when not loading and a load has started and there is no item", arguments: ErrorInput.allCases)
    func neverSpinsForever(errorInput: ErrorInput) {
        let state = ItemDetailScreenState.resolve(
            item: nil, isLoading: false, hasStartedLoading: true, error: errorInput.error
        )

        #expect(state != .loading)
    }

    @Test("no item, not loading, load started, no error is notLoaded (the vanished-error case)")
    func notLoadedWithoutError() {
        let state = ItemDetailScreenState.resolve(item: nil, isLoading: false, hasStartedLoading: true, error: nil)

        #expect(state == .notLoaded)
    }

    @Test("sessionEnded shows no banner: it resolves to notLoaded once a load has started and finished")
    func sessionEndedIsNotLoaded() {
        let state = ItemDetailScreenState.resolve(item: nil, isLoading: false, hasStartedLoading: true, error: .sessionEnded)

        #expect(state == .notLoaded)
    }

    // MARK: Error case

    @Test("the error case carries ItemErrorPresentation.banner(for:hasRetryAction: true)", arguments: [
        ItemError.network, .server, .rateLimited(retryAfter: 3), .invalidResponse, .forbidden, .notFound, .unauthorized
    ])
    func errorCarriesTheBanner(error: ItemError) throws {
        let expected = try #require(ItemErrorPresentation.banner(for: error, hasRetryAction: true))

        let state = ItemDetailScreenState.resolve(item: nil, isLoading: false, hasStartedLoading: true, error: error)

        #expect(state == .error(expected))
    }

    @Test("a retryable error offers Try Again; a non-retryable one does not")
    func errorBannerRetryFlag() throws {
        let retryable = ItemDetailScreenState.resolve(item: nil, isLoading: false, hasStartedLoading: true, error: .network)
        let blocked = ItemDetailScreenState.resolve(item: nil, isLoading: false, hasStartedLoading: true, error: .forbidden)

        guard case .error(let retryableBanner) = retryable, case .error(let blockedBanner) = blocked else {
            Issue.record("expected the .error case for both")
            return
        }
        #expect(retryableBanner.actions.contains(.tryAgain))
        #expect(!blockedBanner.actions.contains(.tryAgain))
        #expect(retryableBanner.message == ItemError.network.userMessage)
    }

    // MARK: Constant

    @Test("the notLoaded text is the agreed message")
    func notLoadedMessage() {
        #expect(ItemDetailScreenState.notLoadedMessage == "This item could not be loaded.")
    }
}
