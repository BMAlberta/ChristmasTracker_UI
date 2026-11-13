//
//  RecordPurchaseErrorTests.swift
//  ChristmasTrackerTests
//
//  Story I4a-A: the user messages and the two behavior flags of PurchaseError.
//  - userMessage is plain text: it never interpolates a payload, an id or a raw error (only the
//    server's own validation message is shown for .validation).
//  - closesForm is true only for .notFound (item or list gone; a 404 is "not found", never
//    "forbidden").
//  - isRetryable is true only for network, server, rateLimited and invalidResponse.
//
//  Fails today because PurchaseError does not exist yet.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("Record purchase error Tests")
struct RecordPurchaseErrorTests {

    // MARK: - Messages

    @Test("Every error has a non-empty user message that equals its errorDescription",
          arguments: PurchaseFixtures.allErrors)
    func messagesExist(error: PurchaseError) {
        #expect(error.userMessage.isEmpty == false)
        #expect(error.errorDescription == error.userMessage)
        #expect(error.localizedDescription == error.userMessage)
    }

    @Test("The fixed errors have pairwise different messages")
    func fixedMessagesAreDistinct() {
        let fixed: [PurchaseError] = [
            .notFound, .unauthorized, .forbidden, .cannotPurchaseOwnList, .invalidPrice,
            .rateLimited(retryAfter: 30), .sessionEnded, .network, .invalidResponse, .server
        ]
        let messages = fixed.map(\.userMessage)
        #expect(Set(messages).count == messages.count)
    }

    @Test("The own-list message is different from the generic forbidden message")
    func ownListMessage() {
        #expect(PurchaseError.cannotPurchaseOwnList.userMessage != PurchaseError.forbidden.userMessage)
    }

    @Test("A validation error shows the server's plain message")
    func validationShowsServerMessage() {
        let error = PurchaseError.validation(message: "Store name must be at most 200 characters")
        #expect(error.userMessage.contains("Store name must be at most 200 characters"))
    }

    @Test("A rate-limit message does not interpolate the retry interval", arguments: [0.5, 1.0, 30.0, 3_600.0])
    func rateLimitMessageIsFixed(retryAfter: TimeInterval) {
        let message = PurchaseError.rateLimited(retryAfter: retryAfter).userMessage
        #expect(message == PurchaseError.rateLimited(retryAfter: 1_234).userMessage)
    }

    @Test("Messages never mention tokens, ids or status codes",
          arguments: PurchaseFixtures.allErrors)
    func messagesAreSafe(error: PurchaseError) {
        let lowered = error.userMessage.lowercased()
        #expect(lowered.contains("token") == false)
        #expect(lowered.contains("user-") == false)
        #expect(lowered.contains("http") == false)
        #expect(lowered.contains("optional(") == false)
    }

    // MARK: - closesForm and isRetryable

    @Test("Only notFound closes the form", arguments: PurchaseFixtures.allErrors)
    func closesFormOnlyForNotFound(error: PurchaseError) {
        #expect(error.closesForm == (error == .notFound), "\(error)")
    }

    @Test("Network, server, rateLimited and invalidResponse are retryable; the rest are not",
          arguments: PurchaseFixtures.allErrors)
    func retryableSet(error: PurchaseError) {
        let expected: Bool
        switch error {
        case .network, .server, .rateLimited, .invalidResponse: expected = true
        case .notFound, .unauthorized, .forbidden, .cannotPurchaseOwnList, .validation, .invalidPrice, .sessionEnded,
             .unconfirmed:
            expected = false
        }
        #expect(error.isRetryable == expected, "\(error)")
    }

    // MARK: - Equatable

    @Test("Associated values take part in equality")
    func equality() {
        #expect(PurchaseError.validation(message: "a") == .validation(message: "a"))
        #expect(PurchaseError.validation(message: "a") != .validation(message: "b"))
        #expect(PurchaseError.rateLimited(retryAfter: 1) == .rateLimited(retryAfter: 1))
        #expect(PurchaseError.rateLimited(retryAfter: 1) != .rateLimited(retryAfter: 2))
        #expect(PurchaseError.network != .server)
    }
}
