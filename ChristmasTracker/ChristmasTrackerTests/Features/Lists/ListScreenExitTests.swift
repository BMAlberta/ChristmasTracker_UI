//
//  ListScreenExitTests.swift
//  ChristmasTrackerTests
//
//  Story I3b-K0: ListScreenExit decides when the detail and edit screens leave because the list
//  is gone or read-only. True exactly for notFound and archivedReadOnly.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("ListScreenExit Tests")
struct ListScreenExitTests {

    /// Every ListError case with its expected answer. The switch has no default, so adding a
    /// ListError case without classifying it here is a compile error in this test.
    nonisolated static func expectsExit(_ error: ListError) -> Bool {
        switch error {
        case .notFound, .archivedReadOnly:
            return true
        case .forbidden, .recipientNotFound, .duplicateRecipientYear, .validation, .rateLimited,
             .unauthorized, .sessionEnded, .network, .invalidResponse, .server:
            return false
        }
    }

    nonisolated static let allCases: [ListError] = [
        .forbidden, .notFound, .recipientNotFound, .duplicateRecipientYear, .archivedReadOnly,
        .validation(message: "Name must be between 1 and 200 characters"),
        .rateLimited(retryAfter: 3), .unauthorized, .sessionEnded, .network, .invalidResponse, .server
    ]

    /// Fails when `allCases` misses a case: the exhaustive switch below must produce the same
    /// number of distinct kinds as the list.
    nonisolated static func kind(_ error: ListError) -> Int {
        switch error {
        case .forbidden: 0
        case .notFound: 1
        case .recipientNotFound: 2
        case .duplicateRecipientYear: 3
        case .archivedReadOnly: 4
        case .validation: 5
        case .rateLimited: 6
        case .unauthorized: 7
        case .sessionEnded: 8
        case .network: 9
        case .invalidResponse: 10
        case .server: 11
        }
    }

    @Test("the local case list covers every ListError case exactly once")
    func caseListIsComplete() {
        let kinds = Set(Self.allCases.map(Self.kind))
        #expect(kinds == Set(0...11))
        #expect(Self.allCases.count == 12)
    }

    @Test("shouldDismissDetail is true exactly for notFound and archivedReadOnly", arguments: ListScreenExitTests.allCases)
    func detailExit(error: ListError) {
        #expect(ListScreenExit.shouldDismissDetail(for: error) == Self.expectsExit(error))
    }

    @Test("shouldDismissEdit is true exactly for notFound and archivedReadOnly", arguments: ListScreenExitTests.allCases)
    func editExit(error: ListError) {
        #expect(ListScreenExit.shouldDismissEdit(for: error) == Self.expectsExit(error))
    }

    @Test("a nil error never dismisses")
    func nilNeverDismisses() {
        #expect(ListScreenExit.shouldDismissDetail(for: nil) == false)
        #expect(ListScreenExit.shouldDismissEdit(for: nil) == false)
    }

    @Test("it agrees with ListErrorPresentation.shouldLeaveScreen", arguments: ListScreenExitTests.allCases)
    func agreesWithPresentation(error: ListError) {
        let leaves = ListErrorPresentation(error).shouldLeaveScreen
        #expect(ListScreenExit.shouldDismissDetail(for: error) == leaves)
        #expect(ListScreenExit.shouldDismissEdit(for: error) == leaves)
    }
}
