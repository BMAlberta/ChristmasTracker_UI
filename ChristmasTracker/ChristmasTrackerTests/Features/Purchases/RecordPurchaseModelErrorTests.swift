//
//  RecordPurchaseModelErrorTests.swift
//  ChristmasTrackerTests
//
//  Story I4a-C (e): every error the service can throw, as the form shows it.
//
//   - a typed RecordPurchaseError -> failed(error) with the banner of RecordPurchaseErrorPresentation
//     (no banner for sessionEnded); .notFound (closesForm) also finishes `itemGone`;
//   - CancellationError (the session ended) -> failed(.sessionEnded), no banner;
//   - any other error -> failed(.server);
//   - retry goes out WITHOUT a token and with the identical draft; dismissError returns to editing;
//   - the error is held in the model only: the service publishes nothing.
//
//  Fails today because RecordPurchaseModel does not exist yet.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("Record purchase model error Tests", .timeLimit(.minutes(1)))
@MainActor
struct RecordPurchaseModelErrorTests {

    private struct UnexpectedError: Error {}

    private func makeSUT() async -> RecordPurchaseModelSUT {
        let sut = await makeRecordPurchaseModelSUT(item: ItemFixtures.item(id: "item-1", quantity: 3))
        sut.fill()
        return sut
    }

    @Test("Every typed error becomes the failed state with the presentation banner",
          arguments: PurchaseFixtures.allErrors)
    func typedErrors(error: RecordPurchaseError) async {
        let sut = await makeSUT()
        sut.repo.enqueueFailure(error)

        await sut.model.recordTapped()

        #expect(sut.model.flow.state == .failed(error))
        #expect(sut.model.errorBanner == RecordPurchaseErrorPresentation.banner(for: error))
        let expectedFinish: RecordPurchaseFinish? = error.closesForm ? RecordPurchaseFinish.itemGone : nil
        #expect(sut.model.finish == expectedFinish)
        #expect(sut.model.fieldsAreReadOnly == false)
        #expect(sut.model.isSubmitting == false)
        #expect(sut.service.isMutating == false)
    }

    @Test("A 404 means the item is gone: the form finishes itemGone")
    func notFoundFinishesItemGone() async {
        let sut = await makeSUT()
        sut.repo.enqueueFailure(RecordPurchaseError.notFound)

        await sut.model.recordTapped()

        #expect(sut.model.finish == .itemGone)
    }

    @Test("Other errors keep the form open", arguments: PurchaseFixtures.allErrors.filter { $0 != .notFound })
    func otherErrorsKeepFormOpen(error: RecordPurchaseError) async {
        let sut = await makeSUT()
        sut.repo.enqueueFailure(error)

        await sut.model.recordTapped()

        #expect(sut.model.finish == nil)
    }

    @Test("A failure shows the Record button again so the user can retry")
    func failedShowsRecordButton() async {
        let sut = await makeSUT()
        sut.repo.enqueueFailure(RecordPurchaseError.network)

        await sut.model.recordTapped()

        #expect(sut.model.showsRecordButton == true)
        #expect(sut.model.canTapRecord == true)
        #expect(sut.model.errorBanner?.message == RecordPurchaseError.network.userMessage)
    }

    @Test("sessionEnded has no banner")
    func sessionEndedNoBanner() async {
        let sut = await makeSUT()
        sut.repo.enqueueFailure(RecordPurchaseError.sessionEnded)

        await sut.model.recordTapped()

        #expect(sut.model.flow.state == .failed(.sessionEnded))
        #expect(sut.model.errorBanner == nil)
    }

    @Test("A teardown during the call (CancellationError from the service) shows no banner")
    func teardownShowsNoBanner() async {
        let sut = await makeSUT()
        sut.repo.enqueue(created: PurchaseFixtures.recordedPurchase(), held: true)
        let task = Task { @MainActor in await sut.model.recordTapped() }
        await sut.repo.gate.nextHeldCall()

        await sut.manager.teardown(reason: .userLogout)
        sut.repo.gate.releaseAll()
        await task.value

        #expect(sut.model.flow.state == .failed(.sessionEnded))
        #expect(sut.model.errorBanner == nil)
        #expect(sut.model.finish == nil, "a stale result is never recorded after the session ended")
    }

    @Test("Any other error becomes the generic server error")
    func unexpectedErrorBecomesServer() async {
        let sut = await makeSUT()
        sut.repo.enqueueFailure(UnexpectedError())

        await sut.model.recordTapped()

        #expect(sut.model.flow.state == .failed(.server))
        #expect(sut.model.errorBanner == RecordPurchaseErrorPresentation.banner(for: .server))
    }

    // MARK: Banner specifics

    @Test("rateLimited is retryable, with Try Again")
    func rateLimited() async throws {
        let sut = await makeSUT()
        sut.repo.enqueueFailure(RecordPurchaseError.rateLimited(retryAfter: 30))

        await sut.model.recordTapped()

        let banner = try #require(sut.model.errorBanner)
        #expect(banner == InlineErrorBannerState(
            message: RecordPurchaseError.rateLimited(retryAfter: 30).userMessage, canRetry: true, isDismissible: true
        ))
    }

    @Test("cannotPurchaseOwnList is not retryable and keeps its plain message")
    func cannotPurchaseOwnList() async throws {
        let sut = await makeSUT()
        sut.repo.enqueueFailure(RecordPurchaseError.cannotPurchaseOwnList)

        await sut.model.recordTapped()

        let banner = try #require(sut.model.errorBanner)
        #expect(banner.message == RecordPurchaseError.cannotPurchaseOwnList.userMessage)
        #expect(banner == InlineErrorBannerState(message: banner.message, canRetry: false, isDismissible: true))
    }

    @Test("validation and invalidPrice show the plain message and are not retryable")
    func validationErrors() async throws {
        for error in [RecordPurchaseError.validation(message: "Total cost must be positive"), .invalidPrice] {
            let sut = await makeSUT()
            sut.repo.enqueueFailure(error)

            await sut.model.recordTapped()

            let banner = try #require(sut.model.errorBanner)
            #expect(banner.message == error.userMessage)
            #expect(banner == InlineErrorBannerState(message: error.userMessage, canRetry: false, isDismissible: true))
        }
    }

    // MARK: Retry and dismiss

    @Test("retry goes out WITHOUT a token with the identical draft, and records on success")
    func retryIdenticalDraftNoToken() async {
        let sut = await makeSUT()
        sut.model.input.quantity = 2
        sut.model.input.storeName = "Fake Store"
        sut.repo.enqueueFailure(RecordPurchaseError.network)
        await sut.model.recordTapped()
        let purchase = PurchaseFixtures.recordedPurchase(id: "purchase-5")
        sut.repo.enqueue(created: purchase)

        await sut.model.retry()

        #expect(sut.repo.callCount == 2)
        #expect(sut.repo.calls[1].token == nil)
        #expect(sut.repo.calls[1].draft == sut.repo.calls[0].draft)
        #expect(sut.model.finish == .recorded(purchase))
        #expect(sut.model.errorBanner == nil)
    }

    @Test("retry clears the banner while the request runs and on success")
    func retryClearsBanner() async {
        let sut = await makeSUT()
        sut.repo.enqueueFailure(RecordPurchaseError.server)
        await sut.model.recordTapped()
        #expect(sut.model.errorBanner != nil)
        sut.repo.enqueue(created: PurchaseFixtures.recordedPurchase(), held: true)

        let task = Task { @MainActor in await sut.model.retry() }
        await sut.repo.gate.nextHeldCall()
        #expect(sut.model.errorBanner == nil)
        #expect(sut.model.isSubmitting == true)

        sut.repo.gate.releaseAll()
        await task.value
        #expect(sut.model.errorBanner == nil)
    }

    @Test("A failed retry shows the new error")
    func retryFailsAgain() async {
        let sut = await makeSUT()
        sut.repo.enqueueFailure(RecordPurchaseError.network)
        await sut.model.recordTapped()
        sut.repo.enqueueFailure(RecordPurchaseError.rateLimited(retryAfter: 5))

        await sut.model.retry()

        #expect(sut.model.flow.state == .failed(.rateLimited(retryAfter: 5)))
    }

    @Test("retry outside the failed state does nothing")
    func retryWhenNotFailed() async {
        let sut = await makeSUT()

        await sut.model.retry()

        #expect(sut.repo.callCount == 0)
        #expect(sut.model.flow.state == .editing)
    }

    @Test("dismissError returns to editing, the banner goes, and a new submit starts fresh without a token")
    func dismissReturnsToEditing() async {
        let sut = await makeSUT()
        sut.repo.enqueueFailure(RecordPurchaseError.network)
        await sut.model.recordTapped()

        sut.model.dismissError()

        #expect(sut.model.flow.state == .editing)
        #expect(sut.model.errorBanner == nil)
        sut.repo.enqueue(created: PurchaseFixtures.recordedPurchase())
        await sut.model.recordTapped()
        #expect(sut.repo.callCount == 2)
        #expect(sut.repo.calls[1].token == nil)
    }

    @Test("After dismissError a retry does nothing: the stored draft was dropped")
    func dismissDropsDraft() async {
        let sut = await makeSUT()
        sut.repo.enqueueFailure(RecordPurchaseError.network)
        await sut.model.recordTapped()

        sut.model.dismissError()
        await sut.model.retry()

        #expect(sut.repo.callCount == 1)
    }

    @Test("A failed confirmed resubmit leaves no token anywhere in the model")
    func failedConfirmedLeavesNoToken() async {
        let sut = await makeSUT()
        sut.enqueueConfirmation(token: RecordPurchaseTestToken.first)
        await sut.model.recordTapped()
        sut.repo.enqueueFailure(RecordPurchaseError.server)

        await sut.model.confirmBudget()

        #expect(sut.model.flow.state == .failed(.server))
        #expect(!String(describing: sut.model.flow).contains(RecordPurchaseTestToken.first))
        #expect(!String(reflecting: sut.model.flow).contains(RecordPurchaseTestToken.first))
        #expect(sut.model.panel == nil)
    }
}
