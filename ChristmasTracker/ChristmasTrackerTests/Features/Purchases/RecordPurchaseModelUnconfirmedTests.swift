//
//  RecordPurchaseModelUnconfirmedTests.swift
//  ChristmasTrackerTests
//
//  Story I4b-C: the unconfirmed-purchase handling of the Record Purchase model.
//
//   - an UNCONFIRMED failure (first submit or confirmed resubmit) shows the banner with the actions
//     Check Item, Record Again, Dismiss and no Try Again;
//   - checkItem() finishes with .checkItem and drops the draft; nothing is sent;
//   - recordAgain() sends a fresh submit with NO token (budget confirmation runs again; a NEW token is
//     used only after Record Anyway);
//   - retry() does nothing for an unconfirmed failure; nothing is ever automatic;
//   - definitive failures keep Try Again and Dismiss exactly as before;
//   - the token never appears in the model's state or descriptions.
//
//  Determinism: the GatedPurchaseRecorder script and its handshake; no sleeps.
//
//  Fails today because RecordPurchaseFinish.checkItem, checkItem(), recordAgain() and the new
//  InlineErrorBannerState initializer do not exist yet.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("Record purchase model unconfirmed Tests", .timeLimit(.minutes(1)))
@MainActor
struct RecordPurchaseModelUnconfirmedTests {

    private static let unconfirmedBanner = InlineErrorBannerState(
        message: "We couldn't confirm whether this purchase was recorded.",
        actions: [.checkItem, .recordAgain, .dismiss]
    )

    private func makeSUT() async -> RecordPurchaseModelSUT {
        let sut = await makeRecordPurchaseModelSUT(item: ItemFixtures.item(id: "item-1", quantity: 3))
        sut.fill()
        return sut
    }

    private func dumpText(_ value: Any) -> String {
        var out = ""
        dump(value, to: &out)
        return out
    }

    // MARK: The failure

    @Test("An unconfirmed first submit shows Check Item, Record Again and Dismiss, and no Try Again")
    func firstSubmit() async {
        let sut = await makeSUT()
        sut.repo.enqueueFailure(PurchaseError.unconfirmed)

        await sut.model.recordTapped()

        #expect(sut.model.flow.state == .failed(.unconfirmed))
        #expect(sut.model.errorBanner == Self.unconfirmedBanner)
        #expect(sut.model.errorBanner?.actions.contains(.tryAgain) == false)
        #expect(sut.model.finish == nil)
        #expect(sut.repo.callCount == 1, "nothing is retried automatically")
        #expect(sut.service.isMutating == false)
    }

    @Test("An unconfirmed confirmed resubmit shows the same banner and sent the first token once")
    func confirmedResubmit() async {
        let sut = await makeSUT()
        await sut.driveToAwaiting(token: RecordPurchaseTestToken.first)
        sut.repo.enqueueFailure(PurchaseError.unconfirmed)

        await sut.model.confirmBudget()

        #expect(sut.model.flow.state == .failed(.unconfirmed))
        #expect(sut.model.errorBanner == Self.unconfirmedBanner)
        #expect(sut.repo.calls.map(\.token) == [nil, RecordPurchaseTestToken.first])
        #expect(sut.model.finish == nil)
    }

    @Test("The unconfirmed banner appears and the form is still editable")
    func formStaysEditable() async {
        let sut = await makeSUT()
        sut.repo.enqueueFailure(PurchaseError.unconfirmed)

        await sut.model.recordTapped()

        #expect(sut.model.fieldsAreReadOnly == false)
        #expect(sut.model.isSubmitting == false)
    }

    // MARK: Check Item

    @Test("Check Item finishes with .checkItem, returns to editing and sends nothing")
    func checkItem() async {
        let sut = await makeSUT()
        sut.repo.enqueueFailure(PurchaseError.unconfirmed)
        await sut.model.recordTapped()

        sut.model.checkItem()

        #expect(sut.model.finish == .checkItem)
        #expect(sut.model.flow.state == .editing)
        #expect(sut.model.errorBanner == nil)
        #expect(sut.repo.callCount == 1)
    }

    @Test("Check Item drops the draft: a later Record Again sends nothing")
    func checkItemDropsDraft() async {
        let sut = await makeSUT()
        sut.repo.enqueueFailure(PurchaseError.unconfirmed)
        await sut.model.recordTapped()
        sut.model.checkItem()

        await sut.model.recordAgain()

        #expect(sut.repo.callCount == 1)
        #expect(sut.model.flow.state == .editing)
    }

    @Test("Check Item outside an unconfirmed failure is ignored")
    func checkItemIgnoredElsewhere() async {
        let sut = await makeSUT()

        sut.model.checkItem()

        #expect(sut.model.finish == nil)
        #expect(sut.model.flow.state == .editing)
        #expect(sut.repo.callCount == 0)
    }

    // MARK: Record Again

    @Test("Record Again sends a fresh submit with no token and the identical draft")
    func recordAgain() async {
        let sut = await makeSUT()
        sut.repo.enqueueFailure(PurchaseError.unconfirmed)
        await sut.model.recordTapped()
        let purchase = PurchaseFixtures.recordedPurchase(id: "purchase-again")
        sut.repo.enqueue(created: purchase)

        await sut.model.recordAgain()

        #expect(sut.repo.callCount == 2)
        #expect(sut.repo.calls.map(\.token) == [nil, nil])
        #expect(sut.repo.calls[1].draft == sut.repo.calls[0].draft)
        #expect(sut.repo.calls[1].itemId == sut.repo.calls[0].itemId)
        #expect(sut.model.finish == .recorded(purchase))
        #expect(sut.model.errorBanner == nil)
    }

    @Test("The form is read-only and submitting while Record Again is in flight")
    func recordAgainInFlight() async {
        let sut = await makeSUT()
        sut.repo.enqueueFailure(PurchaseError.unconfirmed)
        await sut.model.recordTapped()
        sut.repo.enqueue(created: PurchaseFixtures.recordedPurchase(), held: true)

        let task = Task { @MainActor in await sut.model.recordAgain() }
        _ = await sut.repo.gate.nextHeldCall()

        #expect(sut.model.isSubmitting)
        #expect(sut.model.fieldsAreReadOnly)
        #expect(sut.model.errorBanner == nil)

        sut.repo.gate.releaseAll()
        await task.value
    }

    @Test("Record Again can fail unconfirmed again and shows the same banner")
    func recordAgainUnconfirmedAgain() async {
        let sut = await makeSUT()
        sut.repo.enqueueFailure(PurchaseError.unconfirmed)
        sut.repo.enqueueFailure(PurchaseError.unconfirmed)
        await sut.model.recordTapped()

        await sut.model.recordAgain()

        #expect(sut.model.flow.state == .failed(.unconfirmed))
        #expect(sut.model.errorBanner == Self.unconfirmedBanner)
        #expect(sut.repo.callCount == 2, "no automatic third attempt")
    }

    @Test("Record Again goes through the budget confirmation again; a NEW token is used only after Record Anyway")
    func recordAgainRunsBudgetConfirmationAgain() async {
        let sut = await makeSUT()
        await sut.driveToAwaiting(token: RecordPurchaseTestToken.first)
        sut.repo.enqueueFailure(PurchaseError.unconfirmed)
        await sut.model.confirmBudget()
        #expect(sut.model.flow.state == .failed(.unconfirmed))

        sut.enqueueConfirmation(token: RecordPurchaseTestToken.second)
        await sut.model.recordAgain()

        if case .awaitingConfirmation = sut.model.flow.state {
            #expect(sut.model.panel != nil, "the budget warning panel is shown again")
        } else {
            Issue.record("expected the budget confirmation to be shown again, got \(sut.model.flow.state)")
        }
        #expect(sut.repo.calls.map(\.token) == [nil, RecordPurchaseTestToken.first, nil],
                "Record Again carries no token")

        let purchase = PurchaseFixtures.recordedPurchase(id: "purchase-final")
        sut.repo.enqueue(created: purchase)
        await sut.model.confirmBudget()

        #expect(sut.repo.calls.map(\.token) == [nil, RecordPurchaseTestToken.first, nil, RecordPurchaseTestToken.second],
                "the second token is used only after Record Anyway, and the first is never reused")
        #expect(sut.model.finish == .recorded(purchase))
    }

    @Test("Record Again with no unconfirmed failure is ignored")
    func recordAgainIgnoredElsewhere() async {
        let sut = await makeSUT()

        await sut.model.recordAgain()

        #expect(sut.repo.callCount == 0)
        #expect(sut.model.flow.state == .editing)
    }

    @Test("A teardown during Record Again shows no banner and records nothing")
    func teardownDuringRecordAgain() async {
        let sut = await makeSUT()
        sut.repo.enqueueFailure(PurchaseError.unconfirmed)
        await sut.model.recordTapped()
        sut.repo.enqueue(created: PurchaseFixtures.recordedPurchase(), held: true)
        let task = Task { @MainActor in await sut.model.recordAgain() }
        _ = await sut.repo.gate.nextHeldCall()

        await sut.manager.teardown(reason: .userLogout)
        sut.repo.gate.releaseAll()
        await task.value

        #expect(sut.model.flow.state == .failed(.sessionEnded))
        #expect(sut.model.errorBanner == nil)
        #expect(sut.model.finish == nil)
    }

    // MARK: Retry and Dismiss

    @Test("retry() does nothing for an unconfirmed failure")
    func retryIgnored() async {
        let sut = await makeSUT()
        sut.repo.enqueueFailure(PurchaseError.unconfirmed)
        await sut.model.recordTapped()

        await sut.model.retry()

        #expect(sut.repo.callCount == 1)
        #expect(sut.model.flow.state == .failed(.unconfirmed))
        #expect(sut.model.errorBanner == Self.unconfirmedBanner)
    }

    @Test("Dismiss returns to editing without sending anything")
    func dismiss() async {
        let sut = await makeSUT()
        sut.repo.enqueueFailure(PurchaseError.unconfirmed)
        await sut.model.recordTapped()

        sut.model.dismissError()

        #expect(sut.model.flow.state == .editing)
        #expect(sut.model.errorBanner == nil)
        #expect(sut.model.finish == nil)
        #expect(sut.repo.callCount == 1)
    }

    @Test("Cancel closes the form without sending anything")
    func cancel() async {
        let sut = await makeSUT()
        sut.repo.enqueueFailure(PurchaseError.unconfirmed)
        await sut.model.recordTapped()

        sut.model.cancel()

        #expect(sut.model.finish == .cancelled)
        #expect(sut.repo.callCount == 1)
    }

    // MARK: Definitive failures are unchanged

    @Test("A definitive failure keeps Try Again (when retryable) and Dismiss, and never the new actions",
          arguments: PurchaseFixtures.allErrors.filter { $0 != .sessionEnded })
    func definitiveBannerUnchanged(error: PurchaseError) async {
        let sut = await makeSUT()
        sut.repo.enqueueFailure(error)

        await sut.model.recordTapped()

        let expected = InlineErrorBannerState(message: error.userMessage, canRetry: error.isRetryable, isDismissible: true)
        #expect(sut.model.errorBanner == expected)
        #expect(sut.model.errorBanner?.actions.contains(.checkItem) == false)
        #expect(sut.model.errorBanner?.actions.contains(.recordAgain) == false)
    }

    @Test("Check Item and Record Again are ignored after a definitive failure",
          arguments: PurchaseFixtures.allErrors.filter { $0 != .sessionEnded && $0 != .notFound })
    func newEventsIgnoredAfterDefinitive(error: PurchaseError) async {
        let sut = await makeSUT()
        sut.repo.enqueueFailure(error)
        await sut.model.recordTapped()
        let before = sut.model.flow.state

        sut.model.checkItem()
        await sut.model.recordAgain()

        #expect(sut.model.flow.state == before)
        #expect(sut.model.finish == nil)
        #expect(sut.repo.callCount == 1)
    }

    @Test("Retry after a definitive failure still sends again without a token")
    func definitiveRetryUnchanged() async {
        let sut = await makeSUT()
        sut.repo.enqueueFailure(PurchaseError.network)
        await sut.model.recordTapped()
        sut.repo.enqueue(created: PurchaseFixtures.recordedPurchase())

        await sut.model.retry()

        #expect(sut.repo.calls.map(\.token) == [nil, nil])
    }

    // MARK: The token never leaks

    @Test("No token appears in the model's flow state or its descriptions after an unconfirmed failure and Record Again")
    func tokenNeverInState() async {
        let sut = await makeSUT()
        await sut.driveToAwaiting(token: RecordPurchaseTestToken.first)
        sut.repo.enqueueFailure(PurchaseError.unconfirmed)
        await sut.model.confirmBudget()
        sut.enqueueConfirmation(token: RecordPurchaseTestToken.second)
        await sut.model.recordAgain()

        for token in [RecordPurchaseTestToken.first, RecordPurchaseTestToken.second] {
            #expect(!"\(sut.model.flow)".contains(token))
            #expect(!"\(sut.model.flow.state)".contains(token))
            #expect(!String(reflecting: sut.model.flow).contains(token))
            #expect(!dumpText(sut.model.flow).contains(token))
        }
    }

    @Test("No token appears in the flow state or the banner after an unconfirmed confirmed resubmit")
    func tokenNeverInFailedState() async {
        let sut = await makeSUT()
        await sut.driveToAwaiting(token: RecordPurchaseTestToken.first)
        sut.repo.enqueueFailure(PurchaseError.unconfirmed)
        await sut.model.confirmBudget()

        let token = RecordPurchaseTestToken.first
        #expect(!dumpText(sut.model.flow).contains(token))
        #expect(!"\(sut.model.flow.state)".contains(token))
        let bannerText = sut.model.errorBanner?.message ?? ""
        let bannerContainsToken = bannerText.contains(token)
        #expect(bannerContainsToken == false)
        #expect(sut.model.panel == nil)
    }
}
