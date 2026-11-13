//
//  MockPurchaseManagerClearTrackingTests.swift
//  ChristmasTrackerTests
//
//  Story I4c-B (S15): MockPurchaseManager follows `PurchaseShippingUpdate.trackingChange`:
//   - `.unchanged` keeps the stored tracking number, `.set(s)` stores s, `.clear` stores nil;
//   - the status keeps following the S3 rules, also in the same call as a clear;
//   - a shipping update never touches notes, and a notes clear never touches the tracking number;
//   - the mock never stores "" for tracking or notes (asserted on the purchase read back through
//     fetchPurchase). The recorder's own draft handling is not part of this story;
//   - another user's purchase is notFound and changes nothing.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("MockPurchaseManager clearing the tracking number", .timeLimit(.minutes(1)))
struct MockPurchaseManagerClearTrackingTests {

    // MARK: - Clear

    @Test("a clear stores nil, returns nil and keeps the status")
    func clearKeepsStatus() async throws {
        let sut = makeMockManagerSUT()
        let created = try await sut.record(trackingNumber: "TRK-FAKE-0001")
        let shipped = try await sut.manager.updateShipping(
            id: created.id, update: PurchaseShippingUpdate(status: .shipped, trackingChange: .unchanged)
        )

        let cleared = try await sut.manager.updateShipping(
            id: created.id, update: PurchaseShippingUpdate(status: .shipped, trackingChange: .clear)
        )

        #expect(cleared.trackingNumber == nil)
        #expect(cleared.shippingStatus == .shipped)
        #expect(cleared.shippedAt == shipped.shippedAt)
        let readBack = try await sut.manager.fetchPurchase(id: created.id)
        #expect(readBack.trackingNumber == nil)
        #expect(readBack.shippingStatus == .shipped)
    }

    @Test("a clear on a purchase with no tracking number leaves it nil")
    func clearOnEmpty() async throws {
        let sut = makeMockManagerSUT()
        let created = try await sut.record()

        let cleared = try await sut.manager.updateShipping(
            id: created.id, update: PurchaseShippingUpdate(status: .notTracked, trackingChange: .clear)
        )

        #expect(cleared.trackingNumber == nil)
        #expect(try await sut.manager.fetchPurchase(id: created.id).trackingNumber == nil)
    }

    @Test("clearing twice in a row is fine and stays nil")
    func clearTwice() async throws {
        let sut = makeMockManagerSUT()
        let created = try await sut.record(trackingNumber: "TRK-FAKE-0002")
        let clear = PurchaseShippingUpdate(status: .notTracked, trackingChange: .clear)

        _ = try await sut.manager.updateShipping(id: created.id, update: clear)
        let second = try await sut.manager.updateShipping(id: created.id, update: clear)

        #expect(second.trackingNumber == nil)
    }

    @Test("a status change and a clear in one call apply both")
    func statusChangeAndClearInOneCall() async throws {
        let sut = makeMockManagerSUT()
        let created = try await sut.record(trackingNumber: "TRK-FAKE-0003")

        let updated = try await sut.manager.updateShipping(
            id: created.id, update: PurchaseShippingUpdate(status: .delivered, trackingChange: .clear)
        )

        #expect(updated.shippingStatus == .delivered)
        #expect(updated.deliveredAt != nil, "the S3 rules still apply")
        #expect(updated.trackingNumber == nil)
        let readBack = try await sut.manager.fetchPurchase(id: created.id)
        #expect(readBack.shippingStatus == .delivered)
        #expect(readBack.trackingNumber == nil)
    }

    @Test("a clear together with a move back to NOT_SHIPPED clears the timestamps and the tracking number")
    func clearWithMoveBack() async throws {
        let sut = makeMockManagerSUT()
        let created = try await sut.record(trackingNumber: "TRK-FAKE-0004")
        _ = try await sut.manager.updateShipping(
            id: created.id, update: PurchaseShippingUpdate(status: .shipped, trackingChange: .unchanged)
        )

        let back = try await sut.manager.updateShipping(
            id: created.id, update: PurchaseShippingUpdate(status: .notShipped, trackingChange: .clear)
        )

        #expect(back.shippingStatus == .notShipped)
        #expect(back.shippedAt == nil)
        #expect(back.deliveredAt == nil)
        #expect(back.trackingNumber == nil)
    }

    // MARK: - Set and omit

    @Test("a set stores the value and a later read returns it")
    func setStoresTheValue() async throws {
        let sut = makeMockManagerSUT()
        let created = try await sut.record()

        let updated = try await sut.manager.updateShipping(
            id: created.id, update: PurchaseShippingUpdate(status: .shipped, trackingChange: .set("TRK-FAKE-0005"))
        )

        #expect(updated.trackingNumber == "TRK-FAKE-0005")
        #expect(try await sut.manager.fetchPurchase(id: created.id).trackingNumber == "TRK-FAKE-0005")
    }

    @Test("a set replaces an existing value")
    func setReplaces() async throws {
        let sut = makeMockManagerSUT()
        let created = try await sut.record(trackingNumber: "TRK-FAKE-OLD")

        let updated = try await sut.manager.updateShipping(
            id: created.id, update: PurchaseShippingUpdate(status: .shipped, trackingChange: .set("TRK-FAKE-NEW"))
        )

        #expect(updated.trackingNumber == "TRK-FAKE-NEW")
    }

    @Test("an unchanged tracking number keeps the stored value across status changes", arguments: PurchaseShippingStatus.allCases)
    func omitKeepsTheValue(status: PurchaseShippingStatus) async throws {
        let sut = makeMockManagerSUT()
        let created = try await sut.record(trackingNumber: "TRK-FAKE-0006")

        let updated = try await sut.manager.updateShipping(
            id: created.id, update: PurchaseShippingUpdate(status: status, trackingChange: .unchanged)
        )

        #expect(updated.trackingNumber == "TRK-FAKE-0006")
        #expect(try await sut.manager.fetchPurchase(id: created.id).trackingNumber == "TRK-FAKE-0006")
    }

    // MARK: - Notes and tracking are independent

    @Test("a shipping update never touches the notes, whatever the tracking change",
          arguments: [PurchaseTrackingChange.unchanged, .clear, .set("TRK-FAKE-0007")])
    func shippingNeverTouchesNotes(change: PurchaseTrackingChange) async throws {
        let sut = makeMockManagerSUT()
        let created = try await sut.record(notes: "Original note", trackingNumber: "TRK-FAKE-0008")

        let updated = try await sut.manager.updateShipping(
            id: created.id, update: PurchaseShippingUpdate(status: .shipped, trackingChange: change)
        )

        #expect(updated.notes == "Original note")
        #expect(try await sut.manager.fetchPurchase(id: created.id).notes == "Original note")
    }

    @Test("a notes clear clears the notes only and leaves the tracking number")
    func notesClearLeavesTracking() async throws {
        let sut = makeMockManagerSUT()
        let created = try await sut.record(notes: "Original note", trackingNumber: "TRK-FAKE-0009")

        let updated = try await sut.manager.updateNotes(id: created.id, update: PurchaseNotesUpdate(change: .clear))

        #expect(updated.notes == nil)
        #expect(updated.trackingNumber == "TRK-FAKE-0009")
        #expect(try await sut.manager.fetchPurchase(id: created.id).trackingNumber == "TRK-FAKE-0009")
    }

    @Test("a tracking clear does not clear the notes, and a notes clear is the only way to clear them")
    func onlyUpdateNotesClearsNotes() async throws {
        let sut = makeMockManagerSUT()
        let created = try await sut.record(notes: "Original note", trackingNumber: "TRK-FAKE-0010")

        _ = try await sut.manager.updateShipping(
            id: created.id, update: PurchaseShippingUpdate(status: .shipped, trackingChange: .clear)
        )
        #expect(try await sut.manager.fetchPurchase(id: created.id).notes == "Original note")

        _ = try await sut.manager.updateNotes(id: created.id, update: PurchaseNotesUpdate(change: .clear))
        let readBack = try await sut.manager.fetchPurchase(id: created.id)
        #expect(readBack.notes == nil)
        #expect(readBack.trackingNumber == nil)
    }

    // MARK: - Never "" in the store

    @Test("a record with no tracking draft and no notes reads back as nil")
    func recordedWithoutValuesIsNil() async throws {
        let sut = makeMockManagerSUT()
        let created = try await sut.record(notes: nil, trackingNumber: nil)

        let readBack = try await sut.manager.fetchPurchase(id: created.id)

        #expect(readBack.trackingNumber == nil)
        #expect(readBack.notes == nil)
    }

    @Test("setting an empty string never stores an empty string, read back through fetch")
    func setEmptyNeverStoresEmpty() async throws {
        let sut = makeMockManagerSUT()
        let created = try await sut.record(trackingNumber: "TRK-FAKE-0011")

        let updated = try await sut.manager.updateShipping(
            id: created.id, update: PurchaseShippingUpdate(status: .shipped, trackingChange: .set(""))
        )
        let readBack = try await sut.manager.fetchPurchase(id: created.id)

        #expect(updated.trackingNumber != "")
        #expect(readBack.trackingNumber != "")
    }

    @Test("after every kind of shipping update the stored tracking number and notes are never empty strings",
          arguments: [PurchaseTrackingChange.unchanged, .clear, .set("TRK-FAKE-0012")])
    func neverEmptyAfterUpdate(change: PurchaseTrackingChange) async throws {
        let sut = makeMockManagerSUT()
        let created = try await sut.record(notes: "Original note", trackingNumber: "TRK-FAKE-0013")

        _ = try await sut.manager.updateShipping(
            id: created.id, update: PurchaseShippingUpdate(status: .shipped, trackingChange: change)
        )
        _ = try await sut.manager.updateNotes(id: created.id, update: PurchaseNotesUpdate(change: .clear))
        let readBack = try await sut.manager.fetchPurchase(id: created.id)

        #expect(readBack.trackingNumber != "")
        #expect(readBack.notes != "")
    }

    // MARK: - Another user

    @Test("another user's clear is notFound and the owner's tracking number is untouched")
    func otherUserCannotClear() async throws {
        let sut = makeMockManagerSUT()
        let created = try await sut.record(trackingNumber: "TRK-FAKE-0014")
        sut.user.set(MockManagerKit.other.id)

        let error = await sut.managementError {
            _ = try await sut.manager.updateShipping(
                id: created.id, update: PurchaseShippingUpdate(status: .shipped, trackingChange: .clear)
            )
        }
        sut.user.set(MockManagerKit.sam.id)

        #expect(error == .notFound)
        #expect(try await sut.manager.fetchPurchase(id: created.id).trackingNumber == "TRK-FAKE-0014")
    }

    @Test("a clear on a deleted purchase is notFound")
    func clearAfterDeleteIsNotFound() async throws {
        let sut = makeMockManagerSUT()
        let created = try await sut.record(trackingNumber: "TRK-FAKE-0015")
        _ = try await sut.manager.deletePurchase(id: created.id)

        let error = await sut.managementError {
            _ = try await sut.manager.updateShipping(
                id: created.id, update: PurchaseShippingUpdate(status: .shipped, trackingChange: .clear)
            )
        }
        let secondDelete = await sut.managementError { _ = try await sut.manager.deletePurchase(id: created.id) }

        #expect(error == .notFound)
        #expect(secondDelete == .notFound)
    }
}
