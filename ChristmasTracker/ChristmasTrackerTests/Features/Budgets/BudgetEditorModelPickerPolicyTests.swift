//
//  BudgetEditorModelPickerPolicyTests.swift
//  ChristmasTrackerTests
//
//  UX1a Story U3: the budget editor's person picker failure is produced through ScreenLoadPresentation
//  (source .people). The picker has no saved people when its lists load fails (it loads only when the
//  service has none), so the failure is the policy's FULL ERROR: the plain message of the typed error,
//  never the stale-data text, and the rate limit keeps its retry hint. The picker's published shape
//  (`picker == .failed(message:)`) is the existing one. Fake data only.
//
//  Determinism: gated fakes. No sleeps, no yield loops.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("BudgetEditorModel picker policy Tests", .timeLimit(.minutes(1)))
@MainActor
struct BudgetEditorModelPickerPolicyTests {

    private func makeSUT() -> BudgetEditorSUT {
        makeBudgetEditorSUT()
    }

    /// What the policy says the picker shows for this lists failure when there are no saved people.
    private func policyMessage(for error: ListError) throws -> String {
        let presentation = ScreenLoadPresentation.make(
            hasCachedData: false,
            failures: [LoadFailure(error, source: .people)]
        )
        return try #require(presentation.fullError).message
    }

    @Test("a failed lists load shows the policy's plain message in the failed picker",
          arguments: [ListError.network, .server, .invalidResponse, .forbidden, .rateLimited(retryAfter: 30)])
    func failedPickerMessageIsThePolicysFullError(error: ListError) async throws {
        let sut = makeSUT()
        sut.listRepo.enqueueFetchLists(.failure(error))

        await sut.model.loadOptions()

        #expect(sut.model.picker == .failed(message: try policyMessage(for: error)))
    }

    @Test("the failed picker never shows the stale-data text", arguments: [ListError.network, .server])
    func failedPickerIsNeverStale(error: ListError) async {
        let sut = makeSUT()
        sut.listRepo.enqueueFetchLists(.failure(error))

        await sut.model.loadOptions()

        #expect(sut.model.picker != .failed(message: LoadFailurePolicy.staleDataText))
    }

    @Test("the rate limit keeps its retry hint in the failed picker")
    func rateLimitKeepsHint() async {
        let sut = makeSUT()
        sut.listRepo.enqueueFetchLists(.failure(ListError.rateLimited(retryAfter: 30)))

        await sut.model.loadOptions()

        guard case .failed(let message) = sut.model.picker else {
            Issue.record("expected the failed picker")
            return
        }
        #expect(message.contains("30 seconds"))
    }

    @Test("a successful retry after a failed picker load shows the people")
    func retryAfterFailureShowsPeople() async {
        let sut = makeSUT()
        sut.listRepo.enqueueFetchLists(.failure(ListError.network))
        await sut.model.loadOptions()
        sut.listRepo.enqueueFetchLists(.success([EditorTest.list(EditorTest.alex)]))

        await sut.model.loadOptions()

        #expect(sut.model.picker == .ready([EditorTest.alex]))
    }
}
