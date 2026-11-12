//
//  MockPurchaseRecorderAccessTests.swift
//  ChristmasTrackerTests
//
//  Story I4a-B: access and validation rules of MockPurchaseRecorder.
//
//  Rules under test (Gate 1 "Mock rules"):
//   - `access` decides per item id: unknown -> notFound, ownList -> cannotPurchaseOwnList,
//     forbidden -> forbidden, allowed(recipient) proceeds.
//   - quantity < 1 -> validation; a total cost that is not greater than 0, above 999999.99 or with
//     more than two decimals -> invalidPrice.
//   - any quantity >= 1 and any item are accepted (the server is permissive).
//   - a failed request records nothing and consumes no id.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("MockPurchaseRecorder access and validation", .timeLimit(.minutes(1)))
struct MockPurchaseRecorderAccessTests {

    // MARK: Access

    @Test("unknown, ownList and forbidden access map to notFound, cannotPurchaseOwnList and forbidden", arguments: [
        ("item-unknown", PurchaseError.notFound),
        ("item-own", .cannotPurchaseOwnList),
        ("item-forbidden", .forbidden)
    ])
    func accessErrors(itemId: String, expected: PurchaseError) async {
        let sut = makeMockPurchaseSUT()

        await #expect(throws: expected) {
            try await sut.create(itemId: itemId)
        }
    }

    @Test("an access error is thrown before anything else, even for an over-budget amount")
    func accessBeforeBudget() async {
        let sut = makeMockPurchaseSUT()

        await #expect(throws: PurchaseError.cannotPurchaseOwnList) {
            try await sut.create(itemId: "item-own", amount: "9999")
        }
    }

    @Test("a refused request records nothing: the next purchase is mock-purchase-1")
    func refusedRequestConsumesNoId() async throws {
        let sut = makeMockPurchaseSUT()
        _ = await capturePurchaseError { try await sut.create(itemId: "item-forbidden") }
        _ = await capturePurchaseError { try await sut.create(quantity: 0) }
        _ = await capturePurchaseError { try await sut.create(amount: "0") }

        let purchase = try #require(try await sut.created(amount: "50"))

        #expect(purchase.id == "mock-purchase-1", "failed requests consume no id and no spend")
    }

    @Test("the access rule is asked about the item being bought")
    func accessGetsTheItemId() async throws {
        let sut = makeMockPurchaseSUT()

        let forPat = try #require(try await sut.created(itemId: "item-3", amount: "5"))
        let forRobin = try #require(try await sut.created(itemId: "item-b", amount: "5"))

        #expect(forPat.itemId == "item-3")
        #expect(forPat.recipient == MockPurchaseKit.pat)
        #expect(forRobin.itemId == "item-b")
        #expect(forRobin.recipient == MockPurchaseKit.robin)
    }

    // MARK: Quantity

    @Test("a quantity below 1 is a validation error", arguments: [0, -1, -100])
    func quantityBelowOne(quantity: Int) async {
        let sut = makeMockPurchaseSUT()

        let thrown = await capturePurchaseError { try await sut.create(quantity: quantity, amount: "5") }

        guard case .validation = thrown else {
            Issue.record("expected .validation for quantity \(quantity), got \(String(describing: thrown))")
            return
        }
    }

    @Test("any quantity of at least 1 is accepted, with no upper bound", arguments: [1, 2, 5, 99, 1_000])
    func anyQuantityAccepted(quantity: Int) async throws {
        let sut = makeMockPurchaseSUT()

        let purchase = try #require(try await sut.created(quantity: quantity, amount: "5"))

        #expect(purchase.quantity == quantity)
    }

    @Test("any item id the access rule allows is accepted, whatever its status would be")
    func anyAllowedItemAccepted() async throws {
        let sut = makeMockPurchaseSUT()

        for itemId in ["item-1", "item-2", "item-3", "item-b"] {
            let purchase = try #require(try await sut.created(itemId: itemId, amount: "1"))
            #expect(purchase.itemId == itemId)
        }
    }

    // MARK: Price

    @Test("a total cost that is zero, negative, above 999999.99 or has more than two decimals is invalidPrice",
          arguments: ["0", "0.00", "-1", "-0.01", "1000000.00", "1000000", "10.001", "0.001", "999999.995"])
    func invalidPrices(amount: String) async {
        let sut = makeMockPurchaseSUT()

        await #expect(throws: PurchaseError.invalidPrice) {
            try await sut.create(amount: amount)
        }
    }

    @Test("999999.99 passes the price check (it is over budget, so it asks for confirmation instead of failing)")
    func upperPriceBoundPasses() async throws {
        let sut = makeMockPurchaseSUT()

        let answer = try await sut.confirmation(amount: "999999.99")

        #expect(answer != nil)
    }

    @Test("1000000.00 fails the price check")
    func justAboveTheBoundFails() async {
        let sut = makeMockPurchaseSUT()

        await #expect(throws: PurchaseError.invalidPrice) {
            try await sut.create(amount: "1000000.00")
        }
    }

    @Test("0.01 passes the price check and is recorded", arguments: ["0.01", "0.10", "19.99", "50"])
    func smallPricesPass(amount: String) async throws {
        let sut = makeMockPurchaseSUT()

        let purchase = try #require(try await sut.created(amount: amount))

        #expect(purchase.totalCost == MockPurchaseKit.dec(amount))
    }

    // MARK: Actor behavior

    @Test("two sequential calls through the same recorder see each other's spend (one shared state)")
    func sharedState() async throws {
        let sut = makeMockPurchaseSUT()
        _ = try #require(try await sut.created(amount: "40"))

        let answer = try await sut.confirmation(amount: "20")

        #expect(answer != nil, "40 + 20 is over the limit of 50")
    }
}
