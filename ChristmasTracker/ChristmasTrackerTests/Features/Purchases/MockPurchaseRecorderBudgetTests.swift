//
//  MockPurchaseRecorderBudgetTests.swift
//  ChristmasTrackerTests
//
//  Story I4a-B: the budget flow of MockPurchaseRecorder, including decision S12 (the full table).
//
//  Rules under test (Gate 1 "Mock rules"):
//   - within budget: recorded at once (id mock-purchase-N, buyer as purchaser, access recipient as
//     recipient, shippingStatus notTracked, dates from the injected clock); a supplied token is ignored.
//   - over budget (recipient spend + amount > 50, or total spend + amount > 50) WITHOUT a valid
//     token: confirmationRequired with one warning per exceeded level (the recipient warning names
//     the recipient), ONE fresh shared token, and NOTHING recorded.
//   - a valid, unexpired token bound to (item, quantity, amount, recipient spend, total spend)
//     records the purchase.
//   - ANY recorded purchase changes the spend, so every outstanding token stops matching: a repeat
//     over-budget purchase (same item, quantity, amount) returns confirmationRequired AGAIN with a
//     NEW token; the currentSpent in the warning includes the earlier purchase.
//   - an expired, unknown or mismatched token behaves exactly like no token: a fresh
//     confirmationRequired, never an error.
//   - the token lasts MockPurchaseRules.tokenLifetime from the injected clock.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("MockPurchaseRecorder budget flow", .timeLimit(.minutes(1)))
struct MockPurchaseRecorderBudgetTests {

    private func dec(_ text: String) -> Decimal { MockPurchaseKit.dec(text) }

    // MARK: Documented mock data

    @Test("the documented mock rules: both limits are 50 and a token lasts 300 seconds")
    func documentedRules() {
        #expect(MockPurchaseRules.recipientBudgetLimit == 50)
        #expect(MockPurchaseRules.totalBudgetLimit == 50)
        #expect(MockPurchaseRules.tokenLifetime == 300)
    }

    // MARK: Within budget

    @Test("a within-budget purchase is recorded at once with the buyer, the recipient and the clock's dates")
    func withinBudgetIsRecorded() async throws {
        let sut = makeMockPurchaseSUT()

        let purchase = try #require(try await sut.created(itemId: "item-2", quantity: 2, amount: "20"))

        #expect(purchase.id == "mock-purchase-1")
        #expect(purchase.itemId == "item-2")
        #expect(purchase.quantity == 2)
        #expect(purchase.totalCost == dec("20"))
        #expect(purchase.purchaser == MockItemRepository.defaultUser)
        #expect(purchase.recipient == MockPurchaseKit.pat)
        #expect(purchase.shippingStatus == .notTracked)
        #expect(purchase.purchasedAt == PurchaseTestClock.start)
        #expect(purchase.createdAt == PurchaseTestClock.start)
        #expect(purchase.updatedAt == PurchaseTestClock.start)
        #expect(purchase.shippedAt == nil)
        #expect(purchase.deliveredAt == nil)
    }

    @Test("the purchase carries the draft's optional fields")
    func recordedPurchaseCarriesTheDraft() async throws {
        let sut = makeMockPurchaseSUT()

        let outcome = try await sut.create(
            amount: "12.50", storeName: "Fake Store", notes: "A note",
            confirmationNumber: "CONF-1", trackingNumber: "TRK-1"
        )

        guard case .created(let purchase) = outcome else {
            Issue.record("expected .created, got \(outcome)")
            return
        }
        #expect(purchase.storeName == "Fake Store")
        #expect(purchase.notes == "A note")
        #expect(purchase.confirmationNumber == "CONF-1")
        #expect(purchase.trackingNumber == "TRK-1")
        #expect(purchase.totalCost == dec("12.50"))
    }

    @Test("a custom buyer is the purchaser")
    func customBuyer() async throws {
        let buyer = ListItemPerson(id: "user-9", displayName: "Quinn Buyer")
        let sut = makeMockPurchaseSUT(buyer: buyer)

        let purchase = try #require(try await sut.created())

        #expect(purchase.purchaser == buyer)
    }

    @Test("the recipient of a purchase is the one the access rule names")
    func recipientFollowsAccess() async throws {
        let sut = makeMockPurchaseSUT()

        let forRobin = try #require(try await sut.created(itemId: "item-b", amount: "10"))

        #expect(forRobin.recipient == MockPurchaseKit.robin)
    }

    @Test("recorded purchases get ids mock-purchase-1, mock-purchase-2, ...")
    func idsIncrement() async throws {
        let sut = makeMockPurchaseSUT()

        let first = try #require(try await sut.created(amount: "5"))
        let second = try #require(try await sut.created(amount: "5"))
        let third = try #require(try await sut.created(amount: "5"))

        #expect([first.id, second.id, third.id] == ["mock-purchase-1", "mock-purchase-2", "mock-purchase-3"])
    }

    @Test("the dates come from the injected clock")
    func datesFollowTheClock() async throws {
        let sut = makeMockPurchaseSUT()
        sut.clock.advance(by: 3_600)

        let purchase = try #require(try await sut.created(amount: "5"))

        #expect(purchase.purchasedAt == PurchaseTestClock.start.addingTimeInterval(3_600))
    }

    @Test("a purchase exactly at the limit is within budget; one cent more is over")
    func limitBoundary() async throws {
        let sut = makeMockPurchaseSUT()

        _ = try #require(try await sut.created(amount: "50.00"))
        let over = try await sut.confirmation(amount: "0.01")

        #expect(over != nil, "spend 50 plus 0.01 is over the limit of 50")
    }

    @Test("spend accumulates across purchases: 30 then 20 is within budget, then 0.01 is over")
    func spendAccumulates() async throws {
        let sut = makeMockPurchaseSUT()

        _ = try #require(try await sut.created(amount: "30"))
        _ = try #require(try await sut.created(amount: "20"))
        let over = try await sut.confirmation(amount: "0.01")

        #expect(over != nil)
    }

    @Test("a token supplied for a within-budget purchase is ignored and the purchase is recorded")
    func tokenIgnoredWithinBudget() async throws {
        let sut = makeMockPurchaseSUT()

        let purchase = try #require(try await sut.created(amount: "20", token: "tok-fixture-ABC123"))

        #expect(purchase.id == "mock-purchase-1")
    }

    // MARK: Over budget

    @Test("an over-budget request without a token returns the recipient and total warnings with ONE shared token")
    func overBudgetReturnsTwoWarnings() async throws {
        let sut = makeMockPurchaseSUT()

        let answer = try #require(try await sut.confirmation(amount: "60"))

        #expect(answer.token.isEmpty == false)
        #expect(answer.warnings.count == 2)
        let recipient = try #require(answer.warnings.first { $0.level == .recipient })
        let total = try #require(answer.warnings.first { $0.level == .total })
        #expect(recipient.recipientName == "Pat Recipient", "the recipient warning names the recipient")
        #expect(total.recipientName == nil)
        for warning in [recipient, total] {
            #expect(warning.budgetLimit == dec("50"))
            #expect(warning.currentSpent == dec("0"))
            #expect(warning.purchaseAmount == dec("60"))
            #expect(warning.overage == dec("10"))
        }
    }

    @Test("an over-budget request creates nothing: the next within-budget purchase is mock-purchase-1 and uses no spend")
    func confirmationCreatesNothing() async throws {
        let sut = makeMockPurchaseSUT()
        _ = try #require(try await sut.confirmation(amount: "60"))

        let purchase = try #require(try await sut.created(amount: "50"))

        #expect(purchase.id == "mock-purchase-1", "the 200 must not consume a purchase id")
    }

    @Test("a total-only overage names no recipient and has one warning of level total")
    func totalOnlyOverage() async throws {
        let sut = makeMockPurchaseSUT()
        _ = try #require(try await sut.created(itemId: "item-1", amount: "30"))   // Pat: 30
        _ = try #require(try await sut.created(itemId: "item-b", amount: "10"))   // Robin: 10, total 40

        let answer = try #require(try await sut.confirmation(itemId: "item-b", amount: "20"))   // Robin 30, total 60

        #expect(answer.warnings.count == 1)
        let warning = try #require(answer.warnings.first)
        #expect(warning.level == .total)
        #expect(warning.recipientName == nil)
        #expect(warning.currentSpent == dec("40"))
        #expect(warning.purchaseAmount == dec("20"))
        #expect(warning.overage == dec("10"))
    }

    @Test("each confirmation gets a new token")
    func eachConfirmationHasANewToken() async throws {
        let sut = makeMockPurchaseSUT()

        let first = try #require(try await sut.confirmation(amount: "60"))
        let second = try #require(try await sut.confirmation(amount: "60"))

        #expect(first.token != second.token)
    }

    // MARK: Resubmit

    @Test("resubmitting the same request with the token records the purchase")
    func resubmitRecords() async throws {
        let sut = makeMockPurchaseSUT()
        let answer = try #require(try await sut.confirmation(quantity: 2, amount: "60"))

        let purchase = try #require(try await sut.created(quantity: 2, amount: "60", token: answer.token))

        #expect(purchase.id == "mock-purchase-1")
        #expect(purchase.quantity == 2)
        #expect(purchase.totalCost == dec("60"))
    }

    @Test("a token from the second warning list entry works the same: the warnings share one token")
    func sharedTokenWorks() async throws {
        let sut = makeMockPurchaseSUT()
        let answer = try #require(try await sut.confirmation(amount: "75"))
        #expect(answer.warnings.count == 2)

        let purchase = try #require(try await sut.created(amount: "75", token: answer.token))

        #expect(purchase.totalCost == dec("75"))
    }

    // MARK: S12: a repeat over-budget purchase asks again

    @Test("S12: a repeat over-budget purchase returns confirmationRequired AGAIN with a NEW token and the earlier spend")
    func repeatPurchaseAsksAgain() async throws {
        let sut = makeMockPurchaseSUT()
        let first = try #require(try await sut.confirmation(amount: "60"))
        _ = try #require(try await sut.created(amount: "60", token: first.token))

        let second = try #require(try await sut.confirmation(amount: "60"))

        #expect(second.token != first.token)
        let recipient = try #require(second.warnings.first { $0.level == .recipient })
        #expect(recipient.currentSpent == dec("60"), "the warning includes the purchase just recorded")
        #expect(recipient.overage == dec("70"))
        let third = try #require(try await sut.created(amount: "60", token: second.token))
        #expect(third.id == "mock-purchase-2")
    }

    @Test("S12: replaying a used token returns a fresh confirmationRequired and records nothing")
    func replayingAUsedToken() async throws {
        let sut = makeMockPurchaseSUT()
        let answer = try #require(try await sut.confirmation(amount: "60"))
        _ = try #require(try await sut.created(amount: "60", token: answer.token))

        let replay = try #require(try await sut.confirmation(amount: "60", token: answer.token))

        #expect(replay.token != answer.token)
    }

    @Test("S12: a token goes stale as soon as ANOTHER purchase changes the spend")
    func staleTokenAfterAnotherPurchase() async throws {
        let sut = makeMockPurchaseSUT()
        let stale = try #require(try await sut.confirmation(amount: "60"))
        _ = try #require(try await sut.created(itemId: "item-2", amount: "10"))   // changes the spend

        let fresh = try #require(try await sut.confirmation(amount: "60", token: stale.token))

        #expect(fresh.token != stale.token)
        let recipient = try #require(fresh.warnings.first { $0.level == .recipient })
        #expect(recipient.currentSpent == dec("10"))
        let purchase = try #require(try await sut.created(amount: "60", token: fresh.token))
        #expect(purchase.id == "mock-purchase-2", "only the interleaved purchase and this one exist")
    }

    @Test("S12: a purchase for ANOTHER recipient also invalidates the token (the total spend changed)")
    func staleTokenAfterAnotherRecipientPurchase() async throws {
        let sut = makeMockPurchaseSUT()
        let stale = try #require(try await sut.confirmation(amount: "60"))
        _ = try #require(try await sut.created(itemId: "item-b", amount: "10"))

        let fresh = try #require(try await sut.confirmation(amount: "60", token: stale.token))

        #expect(fresh.token != stale.token)
    }

    // MARK: Expiry, unknown, mismatched

    @Test("a token is valid just before tokenLifetime has passed")
    func tokenValidBeforeExpiry() async throws {
        let sut = makeMockPurchaseSUT()
        let answer = try #require(try await sut.confirmation(amount: "60"))
        sut.clock.advance(by: MockPurchaseRules.tokenLifetime - 1)

        let purchase = try await sut.created(amount: "60", token: answer.token)

        #expect(purchase != nil)
    }

    @Test("a token is expired after tokenLifetime: a fresh confirmation, never an error")
    func tokenExpires() async throws {
        let sut = makeMockPurchaseSUT()
        let answer = try #require(try await sut.confirmation(amount: "60"))
        sut.clock.advance(by: MockPurchaseRules.tokenLifetime + 1)

        let fresh = try #require(try await sut.confirmation(amount: "60", token: answer.token))

        #expect(fresh.token != answer.token)
        let next = try #require(try await sut.created(amount: "50"), "nothing was recorded by the expired attempt")
        #expect(next.id == "mock-purchase-1")
    }

    @Test("an unknown token behaves like no token: a fresh confirmation, never an error")
    func unknownToken() async throws {
        let sut = makeMockPurchaseSUT()

        let answer = try #require(try await sut.confirmation(amount: "60", token: "tok-fixture-ABC123"))

        #expect(answer.token != "tok-fixture-ABC123")
        let next = try #require(try await sut.created(amount: "50"))
        #expect(next.id == "mock-purchase-1")
    }

    @Test("a token only matches the request it was issued for: another quantity, amount or item gets a fresh confirmation",
          arguments: [
              (2, "60", "item-1"),   // quantity differs
              (1, "61", "item-1"),   // amount differs
              (1, "60", "item-2")    // item differs (same recipient)
          ])
    func mismatchedToken(quantity: Int, amount: String, itemId: String) async throws {
        let sut = makeMockPurchaseSUT()
        let issued = try #require(try await sut.confirmation(itemId: "item-1", quantity: 1, amount: "60"))

        let fresh = try #require(try await sut.confirmation(
            itemId: itemId, quantity: quantity, amount: amount, token: issued.token
        ))

        #expect(fresh.token != issued.token, "a mismatched token must not record the purchase")
        let next = try #require(try await sut.created(amount: "50"), "nothing was recorded")
        #expect(next.id == "mock-purchase-1")
    }
}
