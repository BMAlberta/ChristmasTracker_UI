//
//  ListErrorTests.swift
//  ChristmasTrackerTests
//
//  Story I3a-L2: ListError.userMessage (pure) and errorDescription.
//
//  Contract: plain messages; documented server message text appears ONLY for `validation`;
//  no ids or names ever; every case has a non-empty message.
//
//  Will not compile until ListError has the new cases and `userMessage`.
//

import Testing
import Foundation
@testable import ChristmasTracker

@Suite("ListError messages")
struct ListErrorTests {

    static let serverText = "Name must be between 1 and 200 characters"

    /// Every case once. `validation` and `rateLimited` use sample associated values.
    nonisolated static let allCases: [ListError] = [
        .forbidden,
        .notFound,
        .recipientNotFound,
        .duplicateRecipientYear,
        .archivedReadOnly,
        .validation(message: serverText),
        .rateLimited(retryAfter: 30),
        .unauthorized,
        .sessionEnded,
        .network,
        .invalidResponse,
        .server
    ]

    /// Cases whose message is fixed text with no server data.
    nonisolated static let fixedCases: [ListError] = [
        .forbidden, .notFound, .recipientNotFound, .duplicateRecipientYear, .archivedReadOnly,
        .unauthorized, .sessionEnded, .network, .invalidResponse, .server
    ]

    @Test("every case has a non-empty user message", arguments: ListErrorTests.allCases)
    func messageIsNotEmpty(error: ListError) {
        #expect(!error.userMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    @Test("errorDescription returns the user message", arguments: ListErrorTests.allCases)
    func errorDescriptionMatchesUserMessage(error: ListError) {
        #expect(error.errorDescription == error.userMessage)
        #expect(error.localizedDescription == error.userMessage)
    }

    @Test("validation shows the server message text")
    func validationShowsServerText() {
        let error = ListError.validation(message: Self.serverText)
        #expect(error.userMessage.contains(Self.serverText))
    }

    @Test("validation shows whatever text the server sent, not a fixed string")
    func validationFollowsTheMessage() {
        let first = ListError.validation(message: "Theme must be at most 500 characters")
        let second = ListError.validation(message: "Year must be between 2000 and 2100")
        #expect(first.userMessage.contains("Theme must be at most 500 characters"))
        #expect(second.userMessage.contains("Year must be between 2000 and 2100"))
        #expect(first.userMessage != second.userMessage)
    }

    @Test("no other case shows the server text", arguments: ListErrorTests.fixedCases)
    func otherCasesDoNotEchoServerText(error: ListError) {
        #expect(!error.userMessage.contains(Self.serverText))
    }

    @Test("messages contain no list id, list name, recipient name or email", arguments: ListErrorTests.allCases)
    func messagesContainNoIdentifiers(error: ListError) {
        for forbidden in ["list-1", "Fake Family List", "Robin", "user-1", "@test.invalid", "@example.invalid"] {
            #expect(!error.userMessage.contains(forbidden))
        }
    }

    @Test("the fixed cases have distinct messages so the user can tell them apart")
    func fixedMessagesAreDistinct() {
        let distinct: [ListError] = [
            .forbidden, .notFound, .recipientNotFound, .duplicateRecipientYear,
            .archivedReadOnly, .network, .invalidResponse, .server
        ]
        let messages = Set(distinct.map(\.userMessage))
        #expect(messages.count == distinct.count)
    }

    @Test("rateLimited has a message for any wait, including zero")
    func rateLimitedMessageForAnyWait() {
        for wait in [0.0, 1.0, 30.0, 600.0] {
            #expect(!ListError.rateLimited(retryAfter: wait).userMessage.isEmpty)
        }
    }

    @Test("ListError is Equatable on its associated values")
    func equatable() {
        #expect(ListError.validation(message: "a") == ListError.validation(message: "a"))
        #expect(ListError.validation(message: "a") != ListError.validation(message: "b"))
        #expect(ListError.rateLimited(retryAfter: 5) == ListError.rateLimited(retryAfter: 5))
        #expect(ListError.rateLimited(retryAfter: 5) != ListError.rateLimited(retryAfter: 6))
        #expect(ListError.notFound != ListError.recipientNotFound)
    }
}
