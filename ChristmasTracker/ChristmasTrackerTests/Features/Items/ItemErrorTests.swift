//
//  ItemErrorTests.swift
//  ChristmasTrackerTests
//
//  Story I3c-B: the expanded ItemError and its plain-message function (Gate 1 addendum).
//  The four legacy cases (fetchFailed, createFailed, updateFailed, deleteFailed) stay until
//  Story C and are not touched here.
//
//  Fails today because the new cases, Equatable conformance and userMessage do not exist yet.
//

import Testing
import Foundation
@testable import ChristmasTracker

@Suite("Item error Tests")
struct ItemErrorTests {

    // MARK: - Factory

    /// Every new case, once. `.validation` uses a server-provided message.
    private func newCases() -> [ItemError] {
        [
            .forbidden,
            .notFound,
            .validation(message: "Name is required"),
            .invalidPrice,
            .cannotDeleteWithPurchases,
            .rateLimited(retryAfter: 30),
            .unauthorized,
            .sessionEnded,
            .network,
            .invalidResponse,
            .server
        ]
    }

    // MARK: - Pinned strings

    @Test("Pinned user messages")
    func pinnedMessages() {
        #expect(ItemError.forbidden.userMessage == "You don't have permission to do that.")
        #expect(ItemError.notFound.userMessage == "This item no longer exists.")
        #expect(ItemError.invalidPrice.userMessage == "Enter a price from 0 to 999,999.99 with at most two decimals.")
        #expect(ItemError.cannotDeleteWithPurchases.userMessage == "This item has purchases and can't be deleted.")
    }

    @Test("validation returns the given message when it is not blank")
    func validationReturnsMessage() {
        #expect(ItemError.validation(message: "Name is required").userMessage == "Name is required")
    }

    @Test("validation falls back to the default text when the message is blank", arguments: ["", "   ", "\n\t "])
    func validationBlankFallsBack(message: String) {
        #expect(ItemError.validation(message: message).userMessage == "Please check the item details and try again.")
    }

    // MARK: - Every other case

    @Test("Every new case has a non-empty message")
    func allMessagesNonEmpty() {
        for error in newCases() {
            #expect(!error.userMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "\(error)")
        }
    }

    @Test("All new cases' messages are pairwise distinct")
    func allMessagesDistinct() {
        let messages = newCases().map(\.userMessage)
        #expect(Set(messages).count == messages.count, "\(messages)")
    }

    @Test("The default validation text differs from every other case's message")
    func defaultValidationTextDistinct() {
        let fallback = ItemError.validation(message: "").userMessage
        for error in newCases() {
            if case .validation = error { continue }
            #expect(error.userMessage != fallback, "\(error)")
        }
    }

    @Test("A rate-limited message does not interpolate the retry value")
    func rateLimitedMessageIsPlain() {
        let short = ItemError.rateLimited(retryAfter: 5).userMessage
        let long = ItemError.rateLimited(retryAfter: 90).userMessage
        #expect(short == long)
        #expect(!long.contains("90"))
    }

    // MARK: - Equatable

    @Test("Cases without payload compare equal to themselves and different to each other")
    func equatableSimpleCases() {
        let simple: [ItemError] = [.forbidden, .notFound, .invalidPrice, .cannotDeleteWithPurchases,
                                   .unauthorized, .sessionEnded, .network, .invalidResponse, .server]
        for (i, lhs) in simple.enumerated() {
            for (j, rhs) in simple.enumerated() {
                #expect((lhs == rhs) == (i == j), "\(lhs) vs \(rhs)")
            }
        }
    }

    @Test("validation compares by message")
    func equatableValidation() {
        #expect(ItemError.validation(message: "a") == ItemError.validation(message: "a"))
        #expect(ItemError.validation(message: "a") != ItemError.validation(message: "b"))
        #expect(ItemError.validation(message: "a") != ItemError.invalidPrice)
    }

    @Test("rateLimited compares by retry interval")
    func equatableRateLimited() {
        #expect(ItemError.rateLimited(retryAfter: 1) == ItemError.rateLimited(retryAfter: 1))
        #expect(ItemError.rateLimited(retryAfter: 1) != ItemError.rateLimited(retryAfter: 2))
        #expect(ItemError.rateLimited(retryAfter: 1) != ItemError.server)
    }

    @Test("ItemError is usable as a thrown, Sendable error")
    func isAnError() {
        let error: any Error = ItemError.notFound
        #expect((error as? ItemError) == .notFound)
        let sendable: any Sendable = ItemError.network
        #expect(sendable is ItemError)
    }
}
