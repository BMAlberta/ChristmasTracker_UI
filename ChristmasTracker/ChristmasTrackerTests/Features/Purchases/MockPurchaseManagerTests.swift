//
//  MockPurchaseManagerTests.swift
//  ChristmasTrackerTests
//
//  Story I4b-B: MockPurchaseManager behaves like the server (Gate 1 Story B interface item 4).
//
//  Rules under test:
//   - OWN purchases only: any other user's purchase, an unknown id, and a missing signed-in user
//     are all `.notFound` (never forbidden), with the same error as a purchase that never existed;
//   - the recorder appends what it creates to the shared store; a recorder without a store records
//     nothing the manager can see;
//   - immutability: notes and shipping only; quantity, total cost, store, confirmation number, item,
//     recipient and purchaser never change;
//   - notes: "" clears to nil, an unchanged update is a 200 no-op;
//   - shipping: sets the status (and the tracking number when given, leaves it when not), with the
//     S3 timestamp rules: moving out of DELIVERED clears deliveredAt; to NOT_SHIPPED or NOT_TRACKED
//     clears both; a timestamp is never invented, a jump to DELIVERED sets deliveredAt only when
//     there is none and leaves shippedAt as it was;
//   - delete returns the deleted purchase and removes it; a second delete is `.notFound`.
//
//  Documented limitation (not tested, by decision): the mock never moves item counts or statuses.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("MockPurchaseManager", .timeLimit(.minutes(1)))
struct MockPurchaseManagerTests {

    // MARK: - Own purchases

    @Test("fetch returns the purchase the recorder created")
    func fetchReturnsTheRecordedPurchase() async throws {
        let sut = makeMockManagerSUT()
        let created = try await sut.record()

        let fetched = try await sut.manager.fetchPurchase(id: created.id)

        #expect(fetched == created)
    }

    @Test("every purchase the recorder creates is visible to the manager")
    func everyRecordedPurchaseIsVisible() async throws {
        let sut = makeMockManagerSUT()
        let first = try await sut.record(amount: "10")
        let second = try await sut.record(amount: "15")

        #expect(first.id != second.id)
        #expect(try await sut.manager.fetchPurchase(id: first.id) == first)
        #expect(try await sut.manager.fetchPurchase(id: second.id) == second)
    }

    @Test("an unknown id is notFound for all four operations")
    func unknownIdIsNotFound() async {
        let sut = makeMockManagerSUT()

        let fetchError = await sut.managementError { _ = try await sut.manager.fetchPurchase(id: "purchase-missing") }
        let notesError = await sut.managementError {
            _ = try await sut.manager.updateNotes(id: "purchase-missing", update: PurchaseNotesUpdate(change: .set("x")))
        }
        let shippingError = await sut.managementError {
            _ = try await sut.manager.updateShipping(
                id: "purchase-missing", update: PurchaseShippingUpdate(status: .shipped, trackingNumber: nil)
            )
        }
        let deleteError = await sut.managementError { _ = try await sut.manager.deletePurchase(id: "purchase-missing") }

        #expect(fetchError == .notFound)
        #expect(notesError == .notFound)
        #expect(shippingError == .notFound)
        #expect(deleteError == .notFound)
    }

    @Test("a recorder created without a store records nothing the manager can see")
    func recorderWithoutAStore() async throws {
        let clock = PurchaseTestClock()
        let access: @Sendable (String) -> MockPurchaseAccess = { MockPurchaseKit.access(for: $0) }
        let recorder = MockPurchaseRecorder(access: access, now: clock.provider)
        let manager = MockPurchaseManager(store: MockPurchaseStore(), currentUserId: { MockItemRepository.defaultUser.id })
        let outcome = try await recorder.createPurchase(
            itemId: "item-1", draft: PurchaseFixtures.draft(totalCost: "10"), confirmationToken: nil
        )
        guard case .created(let created) = outcome else {
            Issue.record("expected .created, got \(outcome)")
            return
        }

        await #expect(throws: PurchaseManagementError.notFound) {
            _ = try await manager.fetchPurchase(id: created.id)
        }
    }

    // MARK: - Another user's purchase, or none

    @Test("another user's purchase is notFound for all four operations, the same error as an unknown id")
    func otherUsersPurchaseIsNotFound() async throws {
        let sut = makeMockManagerSUT()
        let created = try await sut.record()
        sut.user.set(MockManagerKit.other.id)

        let fetchError = await sut.managementError { _ = try await sut.manager.fetchPurchase(id: created.id) }
        let notesError = await sut.managementError {
            _ = try await sut.manager.updateNotes(id: created.id, update: PurchaseNotesUpdate(change: .set("x")))
        }
        let shippingError = await sut.managementError {
            _ = try await sut.manager.updateShipping(
                id: created.id, update: PurchaseShippingUpdate(status: .shipped, trackingNumber: "TRK-FAKE-1")
            )
        }
        let deleteError = await sut.managementError { _ = try await sut.manager.deletePurchase(id: created.id) }
        let unknownError = await sut.managementError { _ = try await sut.manager.fetchPurchase(id: "purchase-missing") }

        #expect(fetchError == .notFound)
        #expect(notesError == .notFound)
        #expect(shippingError == .notFound)
        #expect(deleteError == .notFound)
        #expect(fetchError == unknownError, "a stranger must not be able to tell it from a purchase that never existed")
    }

    @Test("another user's failed attempts change nothing: the owner still sees the untouched purchase")
    func otherUsersAttemptsChangeNothing() async throws {
        let sut = makeMockManagerSUT()
        let created = try await sut.record()
        sut.user.set(MockManagerKit.other.id)

        _ = try? await sut.manager.updateNotes(id: created.id, update: PurchaseNotesUpdate(change: .clear))
        _ = try? await sut.manager.updateShipping(
            id: created.id, update: PurchaseShippingUpdate(status: .delivered, trackingNumber: "TRK-FAKE-1")
        )
        _ = try? await sut.manager.deletePurchase(id: created.id)
        sut.user.set(MockManagerKit.sam.id)

        #expect(try await sut.manager.fetchPurchase(id: created.id) == created)
    }

    @Test("with no signed-in user every operation is notFound")
    func noUserIsNotFound() async throws {
        let sut = makeMockManagerSUT()
        let created = try await sut.record()
        sut.user.set(nil)

        let fetchError = await sut.managementError { _ = try await sut.manager.fetchPurchase(id: created.id) }
        let deleteError = await sut.managementError { _ = try await sut.manager.deletePurchase(id: created.id) }

        #expect(fetchError == .notFound)
        #expect(deleteError == .notFound)
    }

    @Test("an empty signed-in user id owns nothing")
    func emptyUserIdIsNotFound() async throws {
        let sut = makeMockManagerSUT()
        let created = try await sut.record()
        sut.user.set("")

        await #expect(throws: PurchaseManagementError.notFound) {
            _ = try await sut.manager.fetchPurchase(id: created.id)
        }
    }

    @Test("the signed-in user is read on every call: a user switch changes who can open the purchase")
    func userSwitchChangesAccess() async throws {
        let sut = makeMockManagerSUT()
        let created = try await sut.record()

        sut.user.set(MockManagerKit.other.id)
        let asStranger = await sut.managementError { _ = try await sut.manager.fetchPurchase(id: created.id) }
        sut.user.set(MockManagerKit.sam.id)
        let asOwner = try await sut.manager.fetchPurchase(id: created.id)

        #expect(asStranger == .notFound)
        #expect(asOwner == created)
    }

    @Test("a purchase made by another user is not the signed-in user's")
    func purchaseOfAnotherBuyer() async throws {
        let sut = makeMockManagerSUT(buyer: MockManagerKit.other, currentUserId: MockManagerKit.sam.id)
        let created = try await sut.record()

        #expect(created.purchaser.id == MockManagerKit.other.id)
        await #expect(throws: PurchaseManagementError.notFound) {
            _ = try await sut.manager.fetchPurchase(id: created.id)
        }
    }

    // MARK: - Notes

    @Test("setting notes returns the purchase with the new notes and persists them")
    func notesSet() async throws {
        let sut = makeMockManagerSUT()
        let created = try await sut.record(notes: "Original note")

        let updated = try await sut.manager.updateNotes(id: created.id, update: PurchaseNotesUpdate(change: .set("Gift wrap please")))

        #expect(updated.notes == "Gift wrap please")
        #expect(try await sut.manager.fetchPurchase(id: created.id).notes == "Gift wrap please")
    }

    @Test("clearing notes (the empty string on the wire) makes them nil")
    func notesClear() async throws {
        let sut = makeMockManagerSUT()
        let created = try await sut.record(notes: "Original note")

        let updated = try await sut.manager.updateNotes(id: created.id, update: PurchaseNotesUpdate(change: .clear))

        #expect(updated.notes == nil)
        #expect(try await sut.manager.fetchPurchase(id: created.id).notes == nil)
    }

    @Test("an unchanged notes update is a 200 no-op that returns the current purchase")
    func notesUnchanged() async throws {
        let sut = makeMockManagerSUT()
        let created = try await sut.record(notes: "Original note")

        let result = try await sut.manager.updateNotes(id: created.id, update: PurchaseNotesUpdate(change: .unchanged))

        #expect(result.notes == "Original note")
        #expect(result.id == created.id)
        #expect(result.quantity == created.quantity)
        #expect(result.totalCost == created.totalCost)
        #expect(try await sut.manager.fetchPurchase(id: created.id).notes == "Original note")
    }

    @Test("a notes update changes the notes only: every core and shipping field is immutable")
    func notesUpdateIsImmutableElsewhere() async throws {
        let sut = makeMockManagerSUT()
        let created = try await sut.record(quantity: 3, amount: "30", trackingNumber: "TRK-FAKE-7")

        let updated = try await sut.manager.updateNotes(id: created.id, update: PurchaseNotesUpdate(change: .set("New note")))

        #expect(updated.id == created.id)
        #expect(updated.itemId == created.itemId)
        #expect(updated.quantity == created.quantity)
        #expect(updated.totalCost == created.totalCost)
        #expect(updated.storeName == created.storeName)
        #expect(updated.confirmationNumber == created.confirmationNumber)
        #expect(updated.trackingNumber == created.trackingNumber, "the notes call never touches the tracking number")
        #expect(updated.shippingStatus == created.shippingStatus)
        #expect(updated.shippedAt == created.shippedAt)
        #expect(updated.deliveredAt == created.deliveredAt)
        #expect(updated.purchaser == created.purchaser)
        #expect(updated.recipient == created.recipient)
        #expect(updated.item == created.item)
        #expect(updated.purchasedAt == created.purchasedAt)
        #expect(updated.createdAt == created.createdAt)
    }

    // MARK: - Shipping

    @Test("a shipping update sets the status", arguments: PurchaseShippingStatus.allCases)
    func shippingSetsTheStatus(status: PurchaseShippingStatus) async throws {
        let sut = makeMockManagerSUT()
        let created = try await sut.record()

        let updated = try await sut.manager.updateShipping(
            id: created.id, update: PurchaseShippingUpdate(status: status, trackingNumber: nil)
        )

        #expect(updated.shippingStatus == status)
        #expect(try await sut.manager.fetchPurchase(id: created.id).shippingStatus == status)
    }

    @Test("a shipping update sets the tracking number when it carries one")
    func shippingSetsTheTrackingNumber() async throws {
        let sut = makeMockManagerSUT()
        let created = try await sut.record()

        let updated = try await sut.manager.updateShipping(
            id: created.id, update: PurchaseShippingUpdate(status: .shipped, trackingNumber: "TRK-FAKE-0001")
        )

        #expect(updated.trackingNumber == "TRK-FAKE-0001")
        #expect(try await sut.manager.fetchPurchase(id: created.id).trackingNumber == "TRK-FAKE-0001")
    }

    @Test("a shipping update without a tracking number leaves the existing one alone")
    func shippingWithoutTrackingKeepsTheOldOne() async throws {
        let sut = makeMockManagerSUT()
        let created = try await sut.record(trackingNumber: "TRK-FAKE-0002")

        let updated = try await sut.manager.updateShipping(
            id: created.id, update: PurchaseShippingUpdate(status: .shipped, trackingNumber: nil)
        )

        #expect(updated.trackingNumber == "TRK-FAKE-0002")
    }

    @Test("a shipping update changes shipping only: notes and every core field are immutable")
    func shippingUpdateIsImmutableElsewhere() async throws {
        let sut = makeMockManagerSUT()
        let created = try await sut.record(quantity: 3, amount: "30", notes: "Original note")

        let updated = try await sut.manager.updateShipping(
            id: created.id, update: PurchaseShippingUpdate(status: .shipped, trackingNumber: "TRK-FAKE-0003")
        )

        #expect(updated.id == created.id)
        #expect(updated.itemId == created.itemId)
        #expect(updated.quantity == created.quantity)
        #expect(updated.totalCost == created.totalCost)
        #expect(updated.storeName == created.storeName)
        #expect(updated.confirmationNumber == created.confirmationNumber)
        #expect(updated.notes == "Original note")
        #expect(updated.purchaser == created.purchaser)
        #expect(updated.recipient == created.recipient)
        #expect(updated.item == created.item)
        #expect(updated.purchasedAt == created.purchasedAt)
    }

    // MARK: - Shipping timestamps (decision S3)

    private func ship(
        _ sut: MockManagerSUT, _ id: String, _ status: PurchaseShippingStatus
    ) async throws -> RecordedPurchase {
        try await sut.manager.updateShipping(id: id, update: PurchaseShippingUpdate(status: status, trackingNumber: nil))
    }

    @Test("a new purchase has no shipping timestamps and starts NOT_TRACKED")
    func newPurchaseHasNoTimestamps() async throws {
        let sut = makeMockManagerSUT()

        let created = try await sut.record()

        #expect(created.shippingStatus == .notTracked)
        #expect(created.shippedAt == nil)
        #expect(created.deliveredAt == nil)
    }

    @Test("a jump straight to DELIVERED sets deliveredAt and leaves shippedAt as it was (nil)")
    func jumpToDelivered() async throws {
        let sut = makeMockManagerSUT()
        let created = try await sut.record()

        let delivered = try await ship(sut, created.id, .delivered)

        #expect(delivered.shippingStatus == .delivered)
        #expect(delivered.deliveredAt != nil)
        #expect(delivered.shippedAt == nil, "a timestamp is never invented")
    }

    @Test("DELIVERED again keeps the deliveredAt it already has")
    func deliveredTwiceKeepsTheTimestamp() async throws {
        let sut = makeMockManagerSUT()
        let created = try await sut.record()
        let first = try await ship(sut, created.id, .delivered)

        let second = try await ship(sut, created.id, .delivered)

        #expect(first.deliveredAt != nil)
        #expect(second.deliveredAt == first.deliveredAt, "deliveredAt is set only if the purchase has none")
    }

    @Test("moving out of DELIVERED clears deliveredAt and keeps shippedAt")
    func leavingDeliveredClearsDeliveredAt() async throws {
        let sut = makeMockManagerSUT()
        let created = try await sut.record()
        let shipped = try await ship(sut, created.id, .shipped)
        _ = try await ship(sut, created.id, .delivered)

        let back = try await ship(sut, created.id, .shipped)

        #expect(back.deliveredAt == nil)
        #expect(back.shippedAt == shipped.shippedAt, "only deliveredAt is cleared when leaving DELIVERED")
    }

    @Test("moving to NOT_SHIPPED or NOT_TRACKED clears both timestamps",
          arguments: [PurchaseShippingStatus.notShipped, .notTracked], [PurchaseShippingStatus.shipped, .delivered])
    func movingBackClearsBoth(target: PurchaseShippingStatus, from: PurchaseShippingStatus) async throws {
        let sut = makeMockManagerSUT()
        let created = try await sut.record()
        _ = try await ship(sut, created.id, .shipped)
        _ = try await ship(sut, created.id, from)

        let back = try await ship(sut, created.id, target)

        #expect(back.shippingStatus == target)
        #expect(back.shippedAt == nil, "from \(from) to \(target)")
        #expect(back.deliveredAt == nil, "from \(from) to \(target)")
    }

    @Test("after moving back to NOT_SHIPPED a jump to DELIVERED sets deliveredAt only")
    func deliveredAfterBackwardsMove() async throws {
        let sut = makeMockManagerSUT()
        let created = try await sut.record()
        _ = try await ship(sut, created.id, .shipped)
        _ = try await ship(sut, created.id, .notShipped)

        let delivered = try await ship(sut, created.id, .delivered)

        #expect(delivered.deliveredAt != nil)
        #expect(delivered.shippedAt == nil)
    }

    // MARK: - Delete

    @Test("delete returns the deleted purchase and removes it")
    func deleteReturnsAndRemoves() async throws {
        let sut = makeMockManagerSUT()
        let created = try await sut.record()
        let before = try await sut.manager.fetchPurchase(id: created.id)

        let deleted = try await sut.manager.deletePurchase(id: created.id)

        #expect(deleted == before)
        await #expect(throws: PurchaseManagementError.notFound) {
            _ = try await sut.manager.fetchPurchase(id: created.id)
        }
    }

    @Test("a second delete of the same id is notFound")
    func secondDeleteIsNotFound() async throws {
        let sut = makeMockManagerSUT()
        let created = try await sut.record()
        _ = try await sut.manager.deletePurchase(id: created.id)

        await #expect(throws: PurchaseManagementError.notFound) {
            _ = try await sut.manager.deletePurchase(id: created.id)
        }
    }

    @Test("a deleted purchase can no longer be updated")
    func deletedPurchaseCannotBeUpdated() async throws {
        let sut = makeMockManagerSUT()
        let created = try await sut.record()
        _ = try await sut.manager.deletePurchase(id: created.id)

        let notesError = await sut.managementError {
            _ = try await sut.manager.updateNotes(id: created.id, update: PurchaseNotesUpdate(change: .set("x")))
        }
        let shippingError = await sut.managementError {
            _ = try await sut.manager.updateShipping(
                id: created.id, update: PurchaseShippingUpdate(status: .shipped, trackingNumber: nil)
            )
        }

        #expect(notesError == .notFound)
        #expect(shippingError == .notFound)
    }

    @Test("deleting one purchase leaves the others")
    func deleteLeavesOthers() async throws {
        let sut = makeMockManagerSUT()
        let first = try await sut.record(amount: "10")
        let second = try await sut.record(amount: "15")

        _ = try await sut.manager.deletePurchase(id: first.id)

        #expect(try await sut.manager.fetchPurchase(id: second.id) == second)
    }

    @Test("two concurrent deletes of the same id: exactly one succeeds, the other is notFound")
    func concurrentDoubleDelete() async throws {
        let sut = makeMockManagerSUT()
        let created = try await sut.record()
        let manager = sut.manager
        let id = created.id

        async let first: Result<RecordedPurchase, PurchaseManagementError> = Self.deleteResult(manager, id)
        async let second: Result<RecordedPurchase, PurchaseManagementError> = Self.deleteResult(manager, id)
        let results = await [first, second]

        let successes = results.filter { if case .success = $0 { return true } else { return false } }
        let notFounds = results.filter { if case .failure(.notFound) = $0 { return true } else { return false } }
        #expect(successes.count == 1)
        #expect(notFounds.count == 1)
    }

    private nonisolated static func deleteResult(
        _ manager: MockPurchaseManager, _ id: String
    ) async -> Result<RecordedPurchase, PurchaseManagementError> {
        do {
            return .success(try await manager.deletePurchase(id: id))
        } catch let error as PurchaseManagementError {
            return .failure(error)
        } catch {
            return .failure(.server)
        }
    }

    @Test("the mock only ever throws PurchaseManagementError")
    func onlyTypedErrors() async throws {
        let sut = makeMockManagerSUT()

        do {
            _ = try await sut.manager.fetchPurchase(id: "purchase-missing")
            Issue.record("expected an error")
        } catch {
            #expect(error is PurchaseManagementError)
        }
    }
}
