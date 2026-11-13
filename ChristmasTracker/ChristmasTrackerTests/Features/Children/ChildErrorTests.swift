//
//  ChildErrorTests.swift
//  ChristmasTrackerTests
//
//  Story I3b-M1: ChildError messages (pure). Shared cases use the identical text of the
//  matching ListError case; childNotFound and childHasLists have their own exact text.
//

import Testing
import Foundation
@testable import ChristmasTracker

@Suite("ChildError messages")
struct ChildErrorTests {

    static let serverText = "First name must be between 1 and 100 characters"

    /// Every case once. The classifier below has no default, so a new case breaks the build.
    nonisolated static let allCases: [ChildError] = [
        .childNotFound,
        .childHasLists,
        .validation(message: serverText),
        .rateLimited(retryAfter: 30),
        .unauthorized,
        .sessionEnded,
        .network,
        .invalidResponse,
        .server,
        .forbidden
    ]

    /// Exhaustive, no default: adding a ChildError case fails to compile here until it is listed.
    nonisolated static func kind(_ error: ChildError) -> Int {
        switch error {
        case .childNotFound: 0
        case .childHasLists: 1
        case .validation: 2
        case .rateLimited: 3
        case .unauthorized: 4
        case .sessionEnded: 5
        case .network: 6
        case .invalidResponse: 7
        case .server: 8
        case .forbidden: 9
        }
    }

    @Test("the case list covers every ChildError case exactly once")
    func caseListIsComplete() {
        #expect(Set(Self.allCases.map(Self.kind)) == Set(0...9))
        #expect(Self.allCases.count == 10)
    }

    @Test("every case has a non-empty user message", arguments: ChildErrorTests.allCases)
    func messageIsNotEmpty(error: ChildError) {
        #expect(!error.userMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    @Test("errorDescription returns the user message", arguments: ChildErrorTests.allCases)
    func errorDescriptionMatchesUserMessage(error: ChildError) {
        #expect(error.errorDescription == error.userMessage)
        #expect(error.localizedDescription == error.userMessage)
    }

    @Test("childNotFound has its own exact text")
    func childNotFoundText() {
        #expect(ChildError.childNotFound.userMessage == "That child could not be found.")
    }

    // Deliberately changed by I3d-D2 (decision L17): only active lists block a child delete, and
    // the way out is to archive them.
    @Test("childHasLists has its own exact text")
    func childHasListsText() {
        #expect(
            ChildError.childHasLists.userMessage
                == "This child still has active lists. Archive them first."
        )
    }

    @Test("Shared cases use the identical text of the matching ListError case")
    func sharedCasesMatchListError() {
        #expect(ChildError.forbidden.userMessage == ListError.forbidden.userMessage)
        #expect(ChildError.unauthorized.userMessage == ListError.unauthorized.userMessage)
        #expect(ChildError.sessionEnded.userMessage == ListError.sessionEnded.userMessage)
        #expect(ChildError.network.userMessage == ListError.network.userMessage)
        #expect(ChildError.invalidResponse.userMessage == ListError.invalidResponse.userMessage)
        #expect(ChildError.server.userMessage == ListError.server.userMessage)
    }

    @Test("rateLimited matches ListError for any wait", arguments: [0.0, 0.5, 1.0, 30.0, 600.0, 90_000.0])
    func rateLimitedMatchesListError(wait: Double) {
        #expect(
            ChildError.rateLimited(retryAfter: wait).userMessage
                == ListError.rateLimited(retryAfter: wait).userMessage
        )
    }

    @Test("validation passes the server message through and falls back when blank")
    func validationPassesThrough() {
        #expect(ChildError.validation(message: Self.serverText).userMessage.contains(Self.serverText))
        #expect(ChildError.validation(message: "  ").userMessage == ListError.validation(message: "  ").userMessage)
        #expect(!ChildError.validation(message: "").userMessage.isEmpty)
    }

    @Test("no other case shows the server text")
    func otherCasesDoNotEchoServerText() {
        for error in Self.allCases {
            if case .validation = error { continue }
            #expect(!error.userMessage.contains(Self.serverText))
        }
    }

    @Test("messages contain no child id or name", arguments: ChildErrorTests.allCases)
    func messagesContainNoIdentifiers(error: ChildError) {
        for forbidden in ["child-1", "Charlie", "Dana", "user-1"] {
            #expect(!error.userMessage.contains(forbidden))
        }
    }

    @Test("ChildError is Equatable on its associated values")
    func equatable() {
        #expect(ChildError.validation(message: "a") == ChildError.validation(message: "a"))
        #expect(ChildError.validation(message: "a") != ChildError.validation(message: "b"))
        #expect(ChildError.rateLimited(retryAfter: 5) == ChildError.rateLimited(retryAfter: 5))
        #expect(ChildError.rateLimited(retryAfter: 5) != ChildError.rateLimited(retryAfter: 6))
        #expect(ChildError.childNotFound != ChildError.childHasLists)
    }
}
