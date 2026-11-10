//
//  ListErrorPresentationCompletenessTests.swift
//  ChristmasTrackerTests
//
//  Story I3b-M3: the presentation tables cover EVERY ListError case. The switch below has no
//  default, so adding a case without extending the tables stops the build here.
//

import Testing
import Foundation
@testable import ChristmasTracker

@Suite("List error presentation completeness Tests")
struct ListErrorPresentationCompletenessTests {

    private static let caseCount = 15

    /// A distinct index for each case; no `default`, so the compiler enforces exhaustiveness.
    private static func index(_ error: ListError) -> Int {
        switch error {
        case .forbidden: return 0
        case .notFound: return 1
        case .recipientNotFound: return 2
        case .duplicateRecipientYear: return 3
        case .archivedReadOnly: return 4
        case .validation: return 5
        case .rateLimited: return 6
        case .unauthorized: return 7
        case .sessionEnded: return 8
        case .network: return 9
        case .invalidResponse: return 10
        case .server: return 11
        case .memberEmailNotFound: return 12
        case .alreadyMember: return 13
        case .membershipNotFound: return 14
        }
    }

    @Test("The presentation table has every ListError case exactly once")
    func tableCoversEveryCase() {
        let indexes = ListErrorPresentationTests.table.map { Self.index($0.0) }
        #expect(indexes.count == Self.caseCount)
        #expect(Set(indexes) == Set(0..<Self.caseCount))
    }

    @Test("The user-message table has every ListError case exactly once")
    func messageTableCoversEveryCase() {
        let indexes = ListErrorTests.allCases.map { Self.index($0) }
        #expect(Set(indexes) == Set(0..<Self.caseCount))
        #expect(indexes.count == Self.caseCount)
    }

    @Test("Only notFound and archivedReadOnly leave the screen", arguments: ListErrorPresentationTests.table.map(\.0))
    func onlyGoneErrorsLeave(error: ListError) {
        let leaves = ListErrorPresentation(error).shouldLeaveScreen
        let expected = Self.index(error) == 1 || Self.index(error) == 4
        #expect(leaves == expected)
    }

    @Test("Every presentation message is non-empty, equals the user message and has no email",
          arguments: ListErrorPresentationTests.table.map(\.0))
    func messageRules(error: ListError) {
        let presentation = ListErrorPresentation(error)
        #expect(!presentation.message.isEmpty)
        #expect(presentation.message == error.userMessage)
        if Self.index(error) != 5 {
            #expect(!presentation.message.contains("@"))
        }
    }
}
