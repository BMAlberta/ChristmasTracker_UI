//
//  GeneratedClientPurchaseCreateClearResponseTests.swift
//  ChristmasTrackerTests
//
//  Story I4c-B (S15): the record path (createPurchase) gets the same trackingNumber and notes
//  normalization through the shared mapping, pinned on the 201 body through the real factory-built
//  client and the fake transport (a 200 `created` body needs a `warnings` array the contract never
//  sends; that shape is covered in GeneratedClientPurchaseRepositoryTests).
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("GeneratedClientPurchaseRepository response mapping of cleared fields", .timeLimit(.minutes(1)))
struct GeneratedClientPurchaseCreateClearResponseTests {

    private func created(
        status: Int, tracking: ManagementWire.WireText, notes: ManagementWire.WireText
    ) async throws -> RecordedPurchase {
        let sut = try makePurchaseRepoSUT()
        let json = ManagementWire.purchaseJSON(trackingNumber: tracking, notes: notes)
        await sut.transport.enqueue(status: status, json: PurchaseWire.createdEnvelope(purchase: json))
        let outcome = try await sut.create()
        guard case .created(let purchase) = outcome else {
            throw PurchaseError.invalidResponse
        }
        return purchase
    }

    @Test("a created purchase maps trackingNumber null, empty, blank or absent to nil and keeps a value",
          arguments: [201], TextCase.all)
    func trackingNumberMapping(status: Int, textCase: TextCase) async throws {
        let purchase = try await created(status: status, tracking: textCase.wire, notes: .null)

        #expect(purchase.trackingNumber == textCase.expected, "\(status): \(textCase.name)")
    }

    @Test("a created purchase maps notes null, empty, blank or absent to nil and keeps a value",
          arguments: [201], TextCase.all)
    func notesMapping(status: Int, textCase: TextCase) async throws {
        let purchase = try await created(status: status, tracking: .null, notes: textCase.wire)

        #expect(purchase.notes == textCase.expected, "\(status): \(textCase.name)")
    }
}
