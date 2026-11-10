//
//  ListErrorPresentationTests.swift
//  ChristmasTrackerTests
//
//  Story I3a-L3: how every ListError is presented, and the delete confirmation texts.
//

import Testing
import Foundation
@testable import ChristmasTracker

@Suite("List error presentation Tests")
struct ListErrorPresentationTests {

    private func makeSUT(_ error: ListError) -> ListErrorPresentation {
        ListErrorPresentation(error)
    }

    /// Every case of ListError, with the expected (retryable, leavesScreen) pair.
    nonisolated static let table: [(ListError, Bool, Bool)] = [
        (.forbidden, false, false),
        (.notFound, false, true),
        (.recipientNotFound, false, false),
        (.duplicateRecipientYear, false, false),
        (.archivedReadOnly, false, true),
        (.validation(message: "Name is too long."), false, false),
        (.rateLimited(retryAfter: 12), true, false),
        (.unauthorized, false, false),
        (.sessionEnded, false, false),
        (.network, true, false),
        (.invalidResponse, true, false),
        (.server, true, false),
        (.memberEmailNotFound, false, false),
        (.alreadyMember, false, false),
        (.membershipNotFound, false, false)
    ]

    @Test("The message is the error's user message for every case", arguments: table.map(\.0))
    func messageMatches(error: ListError) {
        let presentation = makeSUT(error)
        #expect(presentation.message == error.userMessage)
        #expect(!presentation.message.isEmpty)
    }

    @Test("Retryable only for network, server, rateLimited and invalidResponse", arguments: table)
    func retryable(error: ListError, retryable: Bool, leaves: Bool) {
        #expect(makeSUT(error).isRetryable == retryable)
    }

    @Test("Leaves the screen only for notFound and archivedReadOnly", arguments: table)
    func leavesScreen(error: ListError, retryable: Bool, leaves: Bool) {
        #expect(makeSUT(error).shouldLeaveScreen == leaves)
    }

    @Test("A validation error shows the server text")
    func validationShowsServerText() {
        #expect(makeSUT(.validation(message: "Name is too long.")).message == "Name is too long.")
    }

    @Test("A blank validation message falls back to the plain text, not an empty banner")
    func validationBlankFallsBack() {
        let presentation = makeSUT(.validation(message: "  "))
        #expect(!presentation.message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        #expect(presentation.message == ListError.validation(message: "  ").userMessage)
    }

    @Test("Non-validation messages never contain ids or names", arguments: table.map(\.0))
    func noIdsOrNames(error: ListError) {
        guard case .validation = error else {
            let message = makeSUT(error).message
            #expect(!message.contains("list-"))
            #expect(!message.contains("user-"))
            #expect(!message.contains("Robin"))
            #expect(!message.contains("Fake"))
            return
        }
    }
}
