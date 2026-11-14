//
//  BudgetMappingTests.swift
//  ChristmasTrackerTests
//
//  I5a Story A: mapBudget from literal generated payloads (fake data only).
//

import Foundation
import Testing
import TrackerAPI
@testable import ChristmasTracker

@Suite("mapBudget")
struct BudgetMappingTests {

    private let created = Date(timeIntervalSince1970: 1_767_600_000)
    private let updated = Date(timeIntervalSince1970: 1_767_686_400)

    private func dec(_ text: String) -> Decimal { BudgetFixtures.dec(text) }

    private func recipient(
        id: String = "rb-1",
        recipientId: String = "r1",
        name: String = "Tommy",
        maxSpend: Double = 200,
        spent: Double = 79.99,
        remaining: Double = 120.01,
        isOver: Bool = false,
        overage: Double = 0
    ) -> Components.Schemas.Budget.RecipientsPayloadPayload {
        Components.Schemas.Budget.RecipientsPayloadPayload(
            id: id,
            recipientId: recipientId,
            recipientName: name,
            maxSpend: maxSpend,
            spent: spent,
            remaining: remaining,
            isOverBudget: isOver,
            overage: overage
        )
    }

    private func payload(
        total: Double = 500,
        spent: Double = 79.99,
        remaining: Double = 420.01,
        isOver: Bool = false,
        recipients: [Components.Schemas.Budget.RecipientsPayloadPayload] = []
    ) -> Components.Schemas.Budget {
        Components.Schemas.Budget(
            id: "budget-1",
            year: 2026,
            totalBudget: total,
            totalSpent: spent,
            remaining: remaining,
            isOverBudget: isOver,
            recipients: recipients,
            createdAt: created,
            updatedAt: updated
        )
    }

    @Test func mapsABudgetWithoutRecipients() throws {
        let budget = try mapBudget(payload())
        #expect(budget.id == "budget-1")
        #expect(budget.year == 2026)
        #expect(budget.totalBudget == dec("500"))
        #expect(budget.totalSpent == dec("79.99"))
        #expect(budget.remaining == dec("420.01"))
        #expect(!budget.isOverBudget)
        #expect(budget.recipients.isEmpty)
        #expect(budget.createdAt == created)
        #expect(budget.updatedAt == updated)
    }

    @Test func mapsABudgetWithRecipientsInOrder() throws {
        let budget = try mapBudget(payload(recipients: [
            recipient(),
            recipient(
                id: "rb-2", recipientId: "r2", name: "Mike",
                maxSpend: 600, spent: 619.98, remaining: -19.98, isOver: true, overage: 19.98
            )
        ]))
        #expect(budget.recipients.map(\.recipientId) == ["r1", "r2"])
        let first = try #require(budget.recipients.first)
        #expect(first.id == "rb-1")
        #expect(first.recipientName == "Tommy")
        #expect(first.maxSpend == dec("200"))
        #expect(first.spent == dec("79.99"))
        #expect(first.remaining == dec("120.01"))
        #expect(first.overage == 0)
        #expect(!first.isOverBudget)
        let second = try #require(budget.recipients.last)
        #expect(second.recipientName == "Mike")
        #expect(second.spent == dec("619.98"))
        #expect(second.overage == dec("19.98"))
        #expect(second.isOverBudget)
    }

    @Test func moneyIsExactlyDecimal() throws {
        let budget = try mapBudget(payload(total: 79.99, spent: 0.1, remaining: 79.89))
        #expect(budget.totalBudget == dec("79.99"))
        #expect(budget.totalSpent == dec("0.10"))
        #expect(budget.remaining == dec("79.89"))
    }

    @Test func overBudgetFlagIsCarried() throws {
        let budget = try mapBudget(payload(total: 100, spent: 150, remaining: -50, isOver: true))
        #expect(budget.isOverBudget)
        #expect(budget.remaining == dec("-50"))
    }

    @Test(arguments: [Double.nan, Double.infinity, -Double.infinity])
    func nonFiniteBudgetTotalThrowsInvalidResponse(_ value: Double) {
        #expect(throws: BudgetError.invalidResponse) { try mapBudget(payload(total: value)) }
    }

    @Test func nonFiniteSpentOrRemainingThrowsInvalidResponse() {
        #expect(throws: BudgetError.invalidResponse) { try mapBudget(payload(spent: .nan)) }
        #expect(throws: BudgetError.invalidResponse) { try mapBudget(payload(remaining: .infinity)) }
    }

    @Test func nonFiniteRecipientMoneyThrowsInvalidResponse() {
        #expect(throws: BudgetError.invalidResponse) {
            try mapBudget(payload(recipients: [recipient(maxSpend: .infinity)]))
        }
        #expect(throws: BudgetError.invalidResponse) {
            try mapBudget(payload(recipients: [recipient(spent: .nan)]))
        }
        #expect(throws: BudgetError.invalidResponse) {
            try mapBudget(payload(recipients: [recipient(remaining: .nan)]))
        }
        #expect(throws: BudgetError.invalidResponse) {
            try mapBudget(payload(recipients: [recipient(overage: -Double.infinity)]))
        }
    }
}
