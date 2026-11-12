//
//  PurchaseServicePassThroughTests.swift
//  ChristmasTrackerTests
//
//  Story I4a-B: PurchaseService.recordPurchase passes the repository's answer through.
//
//  Rules under test:
//   - `created` and `confirmationRequired` outcomes come back unchanged (the caller needs the
//     warnings and the token on the first answer).
//   - The arguments reach the repository unchanged (item id, draft, token).
//   - A typed RecordPurchaseError is rethrown as is; any other error becomes `.server`;
//     CancellationError stays CancellationError.
//   - Nothing is published: the service has no error property to read.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("PurchaseService pass-through", .timeLimit(.minutes(1)))
@MainActor
struct PurchaseServicePassThroughTests {

    struct UnrelatedError: Error {}

    // MARK: Outcomes

    @Test("a created outcome is returned unchanged")
    func createdPassesThrough() async throws {
        let sut = await makePurchaseServiceSUT()
        let purchase = PurchaseFixtures.recordedPurchase(id: "purchase-42", quantity: 2)
        sut.repo.enqueue(created: purchase)

        let outcome = try await sut.service.recordPurchase(
            itemId: "item-1", draft: PurchaseFixtures.draft(), confirmationToken: nil
        )

        #expect(outcome == .created(purchase))
    }

    @Test("a confirmationRequired outcome is returned unchanged, warnings and token included")
    func confirmationPassesThrough() async throws {
        let sut = await makePurchaseServiceSUT()
        let warnings = [PurchaseFixtures.recipientWarning(name: "Tommy"), PurchaseFixtures.totalWarning()]
        sut.repo.enqueue(.success(.confirmationRequired(warnings: warnings, token: PurchaseWire.token)))

        let outcome = try await sut.service.recordPurchase(
            itemId: "item-1", draft: PurchaseFixtures.draft(), confirmationToken: nil
        )

        #expect(outcome == .confirmationRequired(warnings: warnings, token: PurchaseWire.token))
    }

    // MARK: Arguments

    @Test("the arguments reach the repository unchanged")
    func argumentsReachTheRepository() async throws {
        let sut = await makePurchaseServiceSUT()
        sut.repo.enqueue(created: PurchaseFixtures.recordedPurchase())
        let draft = PurchaseFixtures.draft(
            quantity: 4, totalCost: "79.99", storeName: "Fake Store", notes: "A note",
            confirmationNumber: "CONF-1", trackingNumber: "TRK-1"
        )

        _ = try await sut.service.recordPurchase(itemId: "item-77", draft: draft, confirmationToken: PurchaseWire.token)

        #expect(sut.repo.calls == [.init(itemId: "item-77", draft: draft, token: PurchaseWire.token)])
    }

    @Test("a call without a token reaches the repository with nil")
    func noTokenMeansNil() async throws {
        let sut = await makePurchaseServiceSUT()
        sut.repo.enqueue(created: PurchaseFixtures.recordedPurchase())

        _ = try await sut.service.recordPurchase(
            itemId: "item-1", draft: PurchaseFixtures.draft(), confirmationToken: nil
        )

        #expect(sut.repo.calls.first?.token == nil)
    }

    // MARK: Errors

    @Test("every RecordPurchaseError is rethrown as is", arguments: PurchaseFixtures.allErrors)
    func typedErrorsAreRethrown(error: RecordPurchaseError) async {
        let sut = await makePurchaseServiceSUT()
        sut.repo.enqueueFailure(error)

        await #expect(throws: error) {
            _ = try await sut.service.recordPurchase(
                itemId: "item-1", draft: PurchaseFixtures.draft(), confirmationToken: nil
            )
        }
        #expect(sut.service.isMutating == false)
    }

    @Test("an error that is not a RecordPurchaseError becomes server", arguments: [
        "unrelated", "url", "item"
    ])
    func untypedErrorsBecomeServer(kind: String) async {
        let sut = await makePurchaseServiceSUT()
        let error: any Error = switch kind {
        case "url": URLError(.notConnectedToInternet)
        case "item": ItemError.network
        default: UnrelatedError()
        }
        sut.repo.enqueueFailure(error)

        await #expect(throws: RecordPurchaseError.server) {
            _ = try await sut.service.recordPurchase(
                itemId: "item-1", draft: PurchaseFixtures.draft(), confirmationToken: nil
            )
        }
    }

    @Test("a repository CancellationError makes the call throw CancellationError, not server")
    func repositoryCancellation() async {
        let sut = await makePurchaseServiceSUT()
        sut.repo.enqueueFailure(CancellationError())

        await #expect(throws: CancellationError.self) {
            _ = try await sut.service.recordPurchase(
                itemId: "item-1", draft: PurchaseFixtures.draft(), confirmationToken: nil
            )
        }
        #expect(sut.service.isMutating == false)
    }

    // MARK: Nothing is published

    @Test("the service has no error property: a failure is thrown to the caller and stored nowhere")
    func noErrorIsPublished() async {
        let sut = await makePurchaseServiceSUT()
        sut.repo.enqueueFailure(RecordPurchaseError.network)
        _ = try? await sut.service.recordPurchase(
            itemId: "item-1", draft: PurchaseFixtures.draft(), confirmationToken: nil
        )

        let labels = Mirror(reflecting: sut.service).children.compactMap(\.label)
        #expect(labels.allSatisfy { !$0.lowercased().contains("error") }, "stored properties: \(labels)")
        var dumped = ""
        for child in Mirror(reflecting: sut.service).children where !(child.value is any PurchaseRecording) {
            dump(child.value, to: &dumped)
        }
        #expect(!dumped.contains("RecordPurchaseError"), "the service must not hold an error value")
    }

    @Test("a second call after a failure starts clean: the earlier error is not carried over")
    func failureDoesNotLeak() async throws {
        let sut = await makePurchaseServiceSUT()
        sut.repo.enqueueFailure(RecordPurchaseError.network)
        sut.repo.enqueue(created: PurchaseFixtures.recordedPurchase())

        _ = try? await sut.service.recordPurchase(
            itemId: "item-1", draft: PurchaseFixtures.draft(), confirmationToken: nil
        )
        let outcome = try await sut.service.recordPurchase(
            itemId: "item-1", draft: PurchaseFixtures.draft(), confirmationToken: nil
        )

        #expect(outcome == .created(PurchaseFixtures.recordedPurchase()))
        #expect(sut.service.isMutating == false)
    }
}
