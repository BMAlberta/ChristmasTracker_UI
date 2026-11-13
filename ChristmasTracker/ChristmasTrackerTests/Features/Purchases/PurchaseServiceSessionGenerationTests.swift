//
//  PurchaseServiceSessionGenerationTests.swift
//  ChristmasTrackerTests
//
//  Story I4c-C: PurchaseService.sessionGeneration is a read-only accessor of the session counter. It
//  changes when the session is cleared and at no other time.
//
//  These tests pin PurchaseService.sessionGeneration.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("Purchase service session generation Tests", .timeLimit(.minutes(1)))
@MainActor
struct PurchaseServiceSessionGenerationTests {

    @Test("A session clear changes the generation; every further clear changes it again")
    func clearChangesGeneration() async {
        let sut = await makeManagementServiceSUT()
        let first = sut.service.sessionGeneration

        await sut.manager.teardown(reason: .userLogout)
        let second = sut.service.sessionGeneration
        await sut.manager.teardown(reason: .userLogout)
        let third = sut.service.sessionGeneration

        #expect(second > first)
        #expect(third > second)
    }

    @Test("Management calls, successful or failed, do not change the generation")
    func callsDoNotChangeGeneration() async throws {
        let sut = await makeManagementServiceSUT()
        let before = sut.service.sessionGeneration
        sut.management.enqueue(PurchaseDetailTest.own())
        sut.management.enqueueFailure(PurchaseManagementError.network)

        _ = try await sut.service.fetchPurchase(id: PurchaseDetailTest.purchaseId)
        _ = try? await sut.service.deletePurchase(id: PurchaseDetailTest.purchaseId)

        #expect(sut.service.sessionGeneration == before)
    }

    @Test("Two services start independent and a clear of one leaves the other alone")
    func servicesAreIndependent() async {
        let one = await makeManagementServiceSUT()
        let two = await makeManagementServiceSUT()
        let before = two.service.sessionGeneration

        await one.manager.teardown(reason: .userLogout)

        #expect(two.service.sessionGeneration == before)
    }
}
