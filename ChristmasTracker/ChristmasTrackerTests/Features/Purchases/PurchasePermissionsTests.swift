//
//  PurchasePermissionsTests.swift
//  ChristmasTrackerTests
//
//  Story I4b-A: PurchasePermissions.canManage is the only place that decides whether a purchase
//  can be opened for management. True only when the signed-in user id is non-nil, non-empty and
//  exactly (case sensitive) equal to the purchaser id. Roles never take part.
//
//  Fails today because PurchasePermissions does not exist yet.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("Purchase permissions Tests")
struct PurchasePermissionsTests {

    private func makeSUT(purchaser: String, current: String?) -> Bool {
        PurchasePermissions.canManage(purchasePurchaserId: purchaser, currentUserId: current)
    }

    @Test("The purchaser can manage their own purchase")
    func ownPurchase() {
        #expect(makeSUT(purchaser: "user-3", current: "user-3"))
    }

    @Test("Another user cannot manage the purchase")
    func otherUser() {
        #expect(!makeSUT(purchaser: "user-3", current: "user-1"))
    }

    @Test("No signed-in user means no management")
    func noCurrentUser() {
        #expect(!makeSUT(purchaser: "user-3", current: nil))
    }

    @Test("An empty current user id never manages, even against an empty purchaser id")
    func emptyCurrentUser() {
        #expect(!makeSUT(purchaser: "user-3", current: ""))
        #expect(!makeSUT(purchaser: "", current: ""))
    }

    @Test("The comparison is exact and case sensitive")
    func caseSensitive() {
        #expect(!makeSUT(purchaser: "User-3", current: "user-3"))
        #expect(!makeSUT(purchaser: "user-3", current: "USER-3"))
    }

    @Test("Surrounding whitespace is not trimmed", arguments: [" user-3", "user-3 ", "user-3\n"])
    func noTrimming(current: String) {
        #expect(!makeSUT(purchaser: "user-3", current: current))
    }

    @Test("An empty purchaser id never matches a real user")
    func emptyPurchaser() {
        #expect(!makeSUT(purchaser: "", current: "user-3"))
    }
}
