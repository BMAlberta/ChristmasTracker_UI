//
//  PurchaseManagementErrorTests.swift
//  ChristmasTrackerTests
//
//  Story I4b-A: the typed errors of get, update, shipping update and delete.
//  - userMessage is plain (never a payload, id or raw error); an empty or blank validation
//    message falls back to "Please check the purchase details and try again.".
//  - isGone is true only for notFound.
//  - keepsScreenOpen is true for everything except notFound, sessionEnded and unauthorized.
//  - isRetryable is true only for network, server, rateLimited and invalidResponse.
//
//  Fails today because PurchaseManagementError does not exist yet.
//

import Foundation
import Testing
@testable import ChristmasTracker

nonisolated enum PurchaseManagementErrorFixtures {
    static let all: [PurchaseManagementError] = [
        .notFound, .unauthorized, .forbidden, .validation(message: "Notes are too long"),
        .rateLimited(retryAfter: 30), .sessionEnded, .network, .invalidResponse, .server
    ]
}

@Suite("Purchase management error Tests")
struct PurchaseManagementErrorTests {

    @Test("Every error has a non-empty message equal to its errorDescription",
          arguments: PurchaseManagementErrorFixtures.all)
    func messagesExist(error: PurchaseManagementError) {
        #expect(!error.userMessage.isEmpty)
        #expect(error.errorDescription == error.userMessage)
        #expect(error.localizedDescription == error.userMessage)
    }

    @Test("The fixed errors have pairwise different messages")
    func fixedMessagesDistinct() {
        let fixed: [PurchaseManagementError] = [
            .notFound, .unauthorized, .forbidden, .rateLimited(retryAfter: 30),
            .sessionEnded, .network, .invalidResponse, .server
        ]
        let messages = fixed.map(\.userMessage)
        #expect(Set(messages).count == messages.count)
    }

    @Test("A validation error shows the server's plain message")
    func validationShowsServerMessage() {
        let error = PurchaseManagementError.validation(message: "Notes must be at most 1000 characters")
        #expect(error.userMessage.contains("Notes must be at most 1000 characters"))
    }

    @Test("An empty or blank validation message falls back to the generic text", arguments: ["", "   ", "\n\t"])
    func validationFallback(message: String) {
        #expect(PurchaseManagementError.validation(message: message).userMessage
                == "Please check the purchase details and try again.")
    }

    @Test("A rate-limit message does not interpolate the retry interval", arguments: [0.5, 30.0, 3_600.0])
    func rateLimitMessageFixed(retryAfter: TimeInterval) {
        #expect(PurchaseManagementError.rateLimited(retryAfter: retryAfter).userMessage
                == PurchaseManagementError.rateLimited(retryAfter: 1_234).userMessage)
    }

    @Test("Messages never mention tokens, ids, status codes or optionals",
          arguments: PurchaseManagementErrorFixtures.all)
    func messagesSafe(error: PurchaseManagementError) {
        let lowered = error.userMessage.lowercased()
        for forbidden in ["token", "user-", "http", "optional("] {
            #expect(!lowered.contains(forbidden), "\(error)")
        }
    }

    @Test("Only notFound is gone", arguments: PurchaseManagementErrorFixtures.all)
    func isGoneOnlyNotFound(error: PurchaseManagementError) {
        #expect(error.isGone == (error == .notFound), "\(error)")
    }

    @Test("Every error keeps the screen open except notFound, sessionEnded and unauthorized",
          arguments: PurchaseManagementErrorFixtures.all)
    func keepsScreenOpen(error: PurchaseManagementError) {
        let leaves = error == .notFound || error == .sessionEnded || error == .unauthorized
        #expect(error.keepsScreenOpen == !leaves, "\(error)")
    }

    @Test("Network, server, rateLimited and invalidResponse are retryable; the rest are not",
          arguments: PurchaseManagementErrorFixtures.all)
    func retryableSet(error: PurchaseManagementError) {
        let expected: Bool
        switch error {
        case .network, .server, .rateLimited, .invalidResponse: expected = true
        case .notFound, .unauthorized, .forbidden, .validation, .sessionEnded: expected = false
        }
        #expect(error.isRetryable == expected, "\(error)")
    }

    @Test("Associated values take part in equality")
    func equality() {
        #expect(PurchaseManagementError.validation(message: "a") == .validation(message: "a"))
        #expect(PurchaseManagementError.validation(message: "a") != .validation(message: "b"))
        #expect(PurchaseManagementError.rateLimited(retryAfter: 1) == .rateLimited(retryAfter: 1))
        #expect(PurchaseManagementError.rateLimited(retryAfter: 1) != .rateLimited(retryAfter: 2))
        #expect(PurchaseManagementError.network != .server)
    }
}
