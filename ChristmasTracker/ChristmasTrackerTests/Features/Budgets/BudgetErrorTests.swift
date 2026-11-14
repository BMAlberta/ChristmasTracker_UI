//
//  BudgetErrorTests.swift
//  ChristmasTrackerTests
//
//  I5a Story A: BudgetError messages and classification, every case.
//

import Foundation
import Testing
@testable import ChristmasTracker

nonisolated struct BudgetErrorCase: Sendable, CustomTestStringConvertible {
    let error: BudgetError
    let message: String
    let isGone: Bool
    let isRetryable: Bool

    var testDescription: String { "\(error)" }
}

@Suite("BudgetError")
struct BudgetErrorTests {

    static let table: [BudgetErrorCase] = [
        BudgetErrorCase(error: .notFound, message: "That budget could not be found.", isGone: true, isRetryable: false),
        BudgetErrorCase(error: .unauthorized, message: "Please sign in again.", isGone: false, isRetryable: false),
        BudgetErrorCase(
            error: .forbidden, message: "You don't have permission to do that.", isGone: false, isRetryable: false
        ),
        BudgetErrorCase(
            error: .rateLimited(retryAfter: 30),
            message: "Too many requests. Please wait a moment and try again.",
            isGone: false, isRetryable: true
        ),
        BudgetErrorCase(
            error: .sessionEnded, message: "Your session has ended. Please sign in again.",
            isGone: false, isRetryable: false
        ),
        BudgetErrorCase(
            error: .network, message: "Check your connection and try again.", isGone: false, isRetryable: true
        ),
        BudgetErrorCase(
            error: .invalidResponse, message: "Something went wrong. Please try again.",
            isGone: false, isRetryable: true
        ),
        BudgetErrorCase(
            error: .server, message: "Something went wrong. Please try again.", isGone: false, isRetryable: true
        ),
        BudgetErrorCase(
            error: .validation(message: ""), message: "Please check the amounts and try again.",
            isGone: false, isRetryable: false
        ),
        BudgetErrorCase(
            error: .alreadyExists(message: ""), message: "You already have a budget for that year.",
            isGone: false, isRetryable: false
        ),
        BudgetErrorCase(
            error: .sumExceedsTotal(message: ""), message: "Limits add up to more than the total",
            isGone: false, isRetryable: false
        ),
        BudgetErrorCase(
            error: .hasPurchases(message: ""), message: "A budget with purchases can't be deleted.",
            isGone: false, isRetryable: false
        )
    ]

    @Test(arguments: table)
    func userMessageIsTheFixedText(_ testCase: BudgetErrorCase) {
        #expect(testCase.error.userMessage == testCase.message)
    }

    @Test(arguments: table)
    func errorDescriptionEqualsUserMessage(_ testCase: BudgetErrorCase) {
        #expect(testCase.error.errorDescription == testCase.error.userMessage)
        #expect(testCase.error.localizedDescription == testCase.message)
    }

    @Test(arguments: table)
    func isGoneIsTrueOnlyForNotFound(_ testCase: BudgetErrorCase) {
        #expect(testCase.error.isGone == testCase.isGone)
    }

    @Test(arguments: table)
    func isRetryableMatchesTheTable(_ testCase: BudgetErrorCase) {
        #expect(testCase.error.isRetryable == testCase.isRetryable)
    }

    // MARK: - Message-carrying cases

    private static let carriers: [(make: @Sendable (String) -> BudgetError, fallback: String)] = [
        ({ BudgetError.validation(message: $0) }, "Please check the amounts and try again."),
        ({ BudgetError.alreadyExists(message: $0) }, "You already have a budget for that year."),
        ({ BudgetError.sumExceedsTotal(message: $0) }, "Limits add up to more than the total"),
        ({ BudgetError.hasPurchases(message: $0) }, "A budget with purchases can't be deleted.")
    ]

    @Test func nonBlankServerMessageIsShownTrimmed() {
        for carrier in Self.carriers {
            #expect(carrier.make("  Server says no.\n").userMessage == "Server says no.")
            #expect(carrier.make("Plain message").userMessage == "Plain message")
        }
    }

    @Test func blankServerMessageFallsBack() {
        for carrier in Self.carriers {
            #expect(carrier.make("").userMessage == carrier.fallback)
            #expect(carrier.make("   ").userMessage == carrier.fallback)
            #expect(carrier.make(" \n\t ").userMessage == carrier.fallback)
        }
    }

    @Test func messageCarriersAreNeverGoneOrRetryable() {
        for carrier in Self.carriers {
            let error = carrier.make("Anything")
            #expect(!error.isGone)
            #expect(!error.isRetryable)
        }
    }

    @Test func errorDescriptionTrimsTheServerMessageToo() {
        #expect(BudgetError.hasPurchases(message: "  Has purchases.  ").errorDescription == "Has purchases.")
    }

    @Test func rateLimitedIsRetryableRegardlessOfTheDelay() {
        #expect(BudgetError.rateLimited(retryAfter: 0).isRetryable)
        #expect(BudgetError.rateLimited(retryAfter: 120).isRetryable)
    }
}
