//
//  PurchaseServiceTokenRetentionTests.swift
//  ChristmasTrackerTests
//
//  Story I4a-B: the confirmation token is used for ONE call and kept nowhere. No property of the
//  service holds it, so a second call without a token goes out without one (a repeat over-budget
//  purchase asks the server again and gets a fresh confirmation), and a reflection of the service
//  never contains the token string, not during the call, not after success, not after a failure.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("PurchaseService token retention", .timeLimit(.minutes(1)))
@MainActor
struct PurchaseServiceTokenRetentionTests {

    /// Everything the service itself stores, dumped. The injected repository is skipped: it is the
    /// test fake, whose call log legitimately records what it was handed.
    private func reflection(of service: PurchaseService) -> String {
        var text = ""
        for child in Mirror(reflecting: service).children {
            if child.value is any PurchaseRecording { continue }
            text += "\(child.label ?? "_"): "
            dump(child.value, to: &text)
        }
        return text + String(describing: service) + String(reflecting: service)
    }

    @Test("a call with a token and then one without: the second reaches the repository with nil")
    func secondCallHasNoToken() async throws {
        let sut = await makePurchaseServiceSUT()
        sut.repo.enqueue(created: PurchaseFixtures.recordedPurchase(id: "purchase-1"))
        sut.repo.enqueue(.success(PurchaseServiceFix.confirmation(token: PurchaseWire.secondToken)))

        _ = try await sut.service.recordPurchase(
            itemId: "item-1", draft: PurchaseFixtures.draft(), confirmationToken: PurchaseWire.token
        )
        _ = try await sut.service.recordPurchase(
            itemId: "item-1", draft: PurchaseFixtures.draft(), confirmationToken: nil
        )

        #expect(sut.repo.calls.map(\.token) == [PurchaseWire.token, nil])
    }

    @Test("a token is not retained after a failed call either: the next call without a token goes out with nil")
    func tokenNotRetainedAfterFailure() async throws {
        let sut = await makePurchaseServiceSUT()
        sut.repo.enqueueFailure(RecordPurchaseError.network)
        sut.repo.enqueue(.success(PurchaseServiceFix.confirmation()))

        _ = try? await sut.service.recordPurchase(
            itemId: "item-1", draft: PurchaseFixtures.draft(), confirmationToken: PurchaseWire.token
        )
        _ = try await sut.service.recordPurchase(
            itemId: "item-1", draft: PurchaseFixtures.draft(), confirmationToken: nil
        )

        #expect(sut.repo.calls.map(\.token) == [PurchaseWire.token, nil])
    }

    @Test("a repeat purchase with no token returns the repository's fresh confirmation, never a reused token")
    func repeatPurchaseGetsAFreshConfirmation() async throws {
        let sut = await makePurchaseServiceSUT()
        sut.repo.enqueue(.success(PurchaseServiceFix.confirmation(token: PurchaseWire.token)))
        sut.repo.enqueue(created: PurchaseFixtures.recordedPurchase())
        sut.repo.enqueue(.success(PurchaseServiceFix.confirmation(token: PurchaseWire.secondToken)))

        let first = try await sut.service.recordPurchase(
            itemId: "item-1", draft: PurchaseFixtures.draft(), confirmationToken: nil
        )
        _ = try await sut.service.recordPurchase(
            itemId: "item-1", draft: PurchaseFixtures.draft(), confirmationToken: PurchaseWire.token
        )
        let repeated = try await sut.service.recordPurchase(
            itemId: "item-1", draft: PurchaseFixtures.draft(), confirmationToken: nil
        )

        #expect(sut.repo.calls.map(\.token) == [nil, PurchaseWire.token, nil])
        #expect(first == PurchaseServiceFix.confirmation(token: PurchaseWire.token))
        #expect(repeated == PurchaseServiceFix.confirmation(token: PurchaseWire.secondToken))
    }

    @Test("a reflection of the service never contains the token, after success, after a failure or after a confirmation")
    func reflectionNeverContainsTheToken() async {
        let sut = await makePurchaseServiceSUT()
        sut.repo.enqueue(created: PurchaseFixtures.recordedPurchase())
        sut.repo.enqueueFailure(RecordPurchaseError.server)
        sut.repo.enqueue(.success(PurchaseServiceFix.confirmation(token: PurchaseWire.secondToken)))

        _ = try? await sut.service.recordPurchase(
            itemId: "item-1", draft: PurchaseFixtures.draft(), confirmationToken: PurchaseWire.token
        )
        _ = try? await sut.service.recordPurchase(
            itemId: "item-1", draft: PurchaseFixtures.draft(), confirmationToken: PurchaseWire.token
        )
        _ = try? await sut.service.recordPurchase(
            itemId: "item-1", draft: PurchaseFixtures.draft(), confirmationToken: nil
        )

        let text = reflection(of: sut.service)
        #expect(!text.contains(PurchaseWire.token))
        #expect(!text.contains(PurchaseWire.secondToken), "the token of a returned confirmation is not kept either")
    }

    @Test("a reflection of the service taken while a call with a token is in flight does not contain the token")
    func reflectionDuringTheCall() async {
        let sut = await makePurchaseServiceSUT()
        sut.repo.enqueue(created: PurchaseFixtures.recordedPurchase(), held: true)
        let task = startRecord(sut.service, token: PurchaseWire.token)
        await sut.repo.gate.nextHeldCall()

        let text = reflection(of: sut.service)
        sut.repo.gate.releaseAll()
        _ = await task.value

        #expect(!text.contains(PurchaseWire.token))
    }

    @Test("a reflection of the service after teardown does not contain the token")
    func reflectionAfterTeardown() async {
        let sut = await makePurchaseServiceSUT()
        sut.repo.enqueue(created: PurchaseFixtures.recordedPurchase(), held: true)
        let task = startRecord(sut.service, token: PurchaseWire.token)
        await sut.repo.gate.nextHeldCall()

        await sut.manager.teardown(reason: .userLogout)
        sut.repo.gate.releaseAll()
        _ = await task.value

        #expect(!reflection(of: sut.service).contains(PurchaseWire.token))
    }
}
