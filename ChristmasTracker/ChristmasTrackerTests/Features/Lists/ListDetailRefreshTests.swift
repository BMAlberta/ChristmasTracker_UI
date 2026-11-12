//
//  ListDetailRefreshTests.swift
//  ChristmasTrackerTests
//
//  Story I3c-F2: the pure pieces behind the detail screen's pull to refresh.
//  - ListDetailRefresh.banner(for:) turns a returned refresh failure into banner state.
//  - ListDetailRefresh.itemsStep chooses between refreshing and loading the items.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("ListDetailRefresh")
struct ListDetailRefreshTests {

    nonisolated static let retryable: [ListError] = [.network, .server, .rateLimited(retryAfter: 5), .invalidResponse]

    nonisolated static let nonRetryable: [ListError] = [
        .forbidden, .notFound, .recipientNotFound, .duplicateRecipientYear, .archivedReadOnly,
        .validation(message: "Fake message"), .unauthorized, .memberEmailNotFound, .alreadyMember,
        .membershipNotFound
    ]

    private static let prefix = "The list could not be refreshed. "

    // MARK: - banner(for:)

    @Test("no error means no banner")
    func nilErrorNoBanner() {
        #expect(ListDetailRefresh.banner(for: nil) == nil)
    }

    @Test("sessionEnded means no banner")
    func sessionEndedNoBanner() {
        #expect(ListDetailRefresh.banner(for: .sessionEnded) == nil)
    }

    @Test("a retryable error shows Try Again then Dismiss", arguments: ListDetailRefreshTests.retryable)
    func retryableBanner(error: ListError) {
        let banner = ListDetailRefresh.banner(for: error)

        #expect(banner?.actions == [.tryAgain, .dismiss])
        #expect(ListErrorPresentation(error).isRetryable)
    }

    @Test("a non-retryable error shows Dismiss only", arguments: ListDetailRefreshTests.nonRetryable)
    func nonRetryableBanner(error: ListError) {
        let banner = ListDetailRefresh.banner(for: error)

        #expect(banner?.actions == [.dismiss])
        #expect(ListErrorPresentation(error).isRetryable == false)
    }

    @Test("the message is the refresh prefix followed by the error's user message",
          arguments: ListDetailRefreshTests.retryable + ListDetailRefreshTests.nonRetryable)
    func messageText(error: ListError) {
        let banner = ListDetailRefresh.banner(for: error)

        #expect(banner?.message == Self.prefix + error.userMessage)
    }

    @Test("the banner equals one built from the same message and flags", arguments: ListDetailRefreshTests.retryable)
    func bannerEqualsBuiltState(error: ListError) {
        let expected = InlineErrorBannerState(
            message: Self.prefix + error.userMessage,
            canRetry: ListErrorPresentation(error).isRetryable,
            isDismissible: true
        )

        #expect(ListDetailRefresh.banner(for: error) == expected)
    }

    @Test("a network error reads as a refresh failure with the network text")
    func networkMessageLiteral() {
        let banner = ListDetailRefresh.banner(for: .network)

        #expect(banner?.message.hasPrefix("The list could not be refreshed. ") == true)
        #expect(banner?.message.hasSuffix(ListError.network.userMessage) == true)
    }

    // MARK: - itemsStep

    @Test("the items are refreshed when the item service already holds this list")
    func sameListRefreshes() {
        #expect(ListDetailRefresh.itemsStep(currentItemsListId: "list-1", listId: "list-1") == .refresh)
    }

    @Test("the items are loaded when the item service holds no list")
    func noListLoads() {
        #expect(ListDetailRefresh.itemsStep(currentItemsListId: nil, listId: "list-1") == .load)
    }

    @Test("the items are loaded when the item service holds another list")
    func otherListLoads() {
        #expect(ListDetailRefresh.itemsStep(currentItemsListId: "list-2", listId: "list-1") == .load)
    }

    @Test("the comparison is exact, not case-insensitive or prefix based")
    func exactComparison() {
        #expect(ListDetailRefresh.itemsStep(currentItemsListId: "LIST-1", listId: "list-1") == .load)
        #expect(ListDetailRefresh.itemsStep(currentItemsListId: "list-10", listId: "list-1") == .load)
    }
}
