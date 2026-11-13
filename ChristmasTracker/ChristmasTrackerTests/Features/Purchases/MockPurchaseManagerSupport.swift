//
//  MockPurchaseManagerSupport.swift
//  ChristmasTrackerTests
//
//  Story I4b-B: shared construction and helpers for the MockPurchaseManager tests.
//
//  The mock manager and the mock recorder share ONE MockPurchaseStore. The tests seed the store
//  through the recorder (the store's own methods are not part of the Gate 1 interface): the
//  recorder is given `store:` and appends what it creates. The signed-in user of the manager is the
//  injected `currentUserId` closure, backed here by a small box a test can change to simulate
//  another user.
//
//  Assumed shapes (Gate 1 Story B interface item 4):
//      MockPurchaseStore()                                              // empty store
//      MockPurchaseRecorder(access:, buyer:, now:, store:)              // `store:` is the last parameter
//      MockPurchaseManager(store:, currentUserId:)
//
//  All ids, names and amounts are fake. The clock is a PurchaseTestClock.
//

import Foundation
import Synchronization
import Testing
@testable import ChristmasTracker

/// The signed-in user id the mock manager reads, changeable by a test.
nonisolated final class CurrentUserBox: Sendable {
    private let value: Mutex<String?>

    init(_ id: String?) {
        value = Mutex(id)
    }

    func set(_ id: String?) {
        value.withLock { $0 = id }
    }

    var closure: @Sendable () -> String? {
        { [self] in self.value.withLock { $0 } }
    }
}

nonisolated enum MockManagerKit {
    static let sam = ListItemPerson(id: "user-3", displayName: "Sam Buyer")
    static let other = ListItemPerson(id: "user-9", displayName: "Alex Stranger")
}

struct MockManagerSUT {
    let recorder: MockPurchaseRecorder
    let manager: MockPurchaseManager
    let store: MockPurchaseStore
    let user: CurrentUserBox
    let clock: PurchaseTestClock

    /// Records a purchase through the recorder (which appends it to the store) and returns it.
    func record(
        itemId: String = "item-1",
        quantity: Int = 2,
        amount: String = "20",
        storeName: String? = "Fake Store",
        notes: String? = "Original note",
        confirmationNumber: String? = "CONF-1",
        trackingNumber: String? = nil,
        sourceLocation: SourceLocation = #_sourceLocation
    ) async throws -> RecordedPurchase {
        let draft = PurchaseFixtures.draft(
            quantity: quantity, totalCost: amount, storeName: storeName, notes: notes,
            confirmationNumber: confirmationNumber, trackingNumber: trackingNumber
        )
        let outcome = try await recorder.createPurchase(itemId: itemId, draft: draft, confirmationToken: nil)
        guard case .created(let purchase) = outcome else {
            Issue.record("expected .created, got \(outcome)", sourceLocation: sourceLocation)
            throw PurchaseManagementError.server
        }
        return purchase
    }

    /// The PurchaseManagementError the body threw (nil when it threw nothing or something else).
    func managementError(_ body: () async throws -> Void) async -> PurchaseManagementError? {
        do {
            try await body()
            return nil
        } catch {
            return error as? PurchaseManagementError
        }
    }
}

func makeMockManagerSUT(
    buyer: ListItemPerson = MockManagerKit.sam,
    currentUserId: String? = MockManagerKit.sam.id
) -> MockManagerSUT {
    let clock = PurchaseTestClock()
    let store = MockPurchaseStore()
    let user = CurrentUserBox(currentUserId)
    let access: @Sendable (String) -> MockPurchaseAccess = { MockPurchaseKit.access(for: $0) }
    let recorder = MockPurchaseRecorder(access: access, buyer: buyer, now: clock.provider, store: store)
    let manager = MockPurchaseManager(store: store, currentUserId: user.closure)
    return MockManagerSUT(recorder: recorder, manager: manager, store: store, user: user, clock: clock)
}
