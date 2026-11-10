//
//  ChildErrorPresentationTests.swift
//  ChristmasTrackerTests
//
//  Story I3b-M1: how every ChildError is presented. Retryable for network, server,
//  rateLimited and invalidResponse only.
//

import Testing
import Foundation
@testable import ChristmasTracker

@Suite("Child error presentation Tests")
struct ChildErrorPresentationTests {

    private func makeSUT(_ error: ChildError) -> ChildErrorPresentation {
        ChildErrorPresentation(error)
    }

    /// Every case with its expected retryable flag.
    nonisolated static let table: [(ChildError, Bool)] = [
        (.childNotFound, false),
        (.childHasLists, false),
        (.validation(message: "First name is too long."), false),
        (.rateLimited(retryAfter: 12), true),
        (.unauthorized, false),
        (.sessionEnded, false),
        (.network, true),
        (.invalidResponse, true),
        (.server, true),
        (.forbidden, false)
    ]

    @Test("The table covers every ChildError case")
    func tableIsComplete() {
        #expect(Set(Self.table.map { ChildErrorTests.kind($0.0) }) == Set(0...9))
    }

    @Test("The message is the error's user message for every case", arguments: table.map(\.0))
    func messageMatches(error: ChildError) {
        let presentation = makeSUT(error)
        #expect(presentation.message == error.userMessage)
        #expect(!presentation.message.isEmpty)
    }

    @Test("Retryable only for network, server, rateLimited and invalidResponse", arguments: table)
    func retryable(error: ChildError, retryable: Bool) {
        #expect(makeSUT(error).isRetryable == retryable)
    }

    @Test("A validation error shows the server text")
    func validationShowsServerText() {
        #expect(makeSUT(.validation(message: "First name is too long.")).message == "First name is too long.")
    }
}
