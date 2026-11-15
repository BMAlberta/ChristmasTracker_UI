//
//  PurchaseHistoryErrorTests.swift
//  ChristmasTrackerTests
//
//  PH1-H1: PurchaseHistoryError is Equatable and every case reads as a non-empty message.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("PurchaseHistoryError", .timeLimit(.minutes(1)))
struct PurchaseHistoryErrorTests {

    nonisolated static let allCases: [PurchaseHistoryError] = [
        .unauthorized, .forbidden, .notFound, .validation(message: "Year is invalid"),
        .validation(message: ""), .rateLimited(retryAfter: 0), .rateLimited(retryAfter: 30),
        .network, .server, .invalidResponse, .sessionEnded
    ]

    @Test("every case has a non-empty user message", arguments: allCases)
    func userMessageIsNeverEmpty(error: PurchaseHistoryError) {
        #expect(error.userMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
    }

    @Test("a validation error keeps its message")
    func validationKeepsMessage() {
        #expect(PurchaseHistoryError.validation(message: "A") == .validation(message: "A"))
        #expect(PurchaseHistoryError.validation(message: "A") != .validation(message: "B"))
    }

    @Test("a rate limit keeps its retry delay")
    func rateLimitKeepsDelay() {
        #expect(PurchaseHistoryError.rateLimited(retryAfter: 3) == .rateLimited(retryAfter: 3))
        #expect(PurchaseHistoryError.rateLimited(retryAfter: 3) != .rateLimited(retryAfter: 4))
    }

    @Test("different cases are not equal")
    func casesDiffer() {
        #expect(PurchaseHistoryError.network != .server)
        #expect(PurchaseHistoryError.unauthorized != .sessionEnded)
        #expect(PurchaseHistoryError.forbidden != .notFound)
    }

    @Test("a not found message does not read as a permission message")
    func notFoundIsNotForbidden() {
        #expect(PurchaseHistoryError.notFound.userMessage != PurchaseHistoryError.forbidden.userMessage)
    }
}
