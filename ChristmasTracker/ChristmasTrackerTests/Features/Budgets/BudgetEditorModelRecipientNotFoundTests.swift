//
//  BudgetEditorModelRecipientNotFoundTests.swift
//  ChristmasTrackerTests
//
//  I5b Story B: a save that fails with BudgetError.recipientNotFound (a person in the request cannot be
//  added) in create and edit mode. The form values are kept, the editor stays open (save returns nil),
//  the banner shows INSIDE the editor with the fixed message (no name, Dismiss only), the budget is not
//  treated as gone (a cached budget survives), and the person options are refreshed by a FORCED lists
//  load: a fetch happens even though the service already holds lists. Also pinned: .notFound on update is
//  still the plain "not found" banner, and other failures do not refresh the people.
//
//  Assumption pinned here: the refresh finishes before save() returns (it is awaited inside save).
//
//  Determinism: gated fakes with plain enqueue. No sleeps, no yield loops. All names are fake.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("BudgetEditorModel recipient not found Tests", .timeLimit(.minutes(1)))
@MainActor
struct BudgetEditorModelRecipientNotFoundTests {

    private static let message =
        "One of the people you chose can't be added to your budget right now. Check the list and try again."

    private let fixtureNames = ["Alex Giftee", "Casey Spender", "Drew Otherson", "Tommy", "Mike"]

    /// An editor whose people are loaded (alex and casey), with alex added to a valid create draft.
    private func makeLoadedCreateSUT() async -> BudgetEditorSUT {
        let sut = makeBudgetEditorSUT()
        sut.listRepo.enqueueFetchLists(.success([EditorTest.list(EditorTest.alex), EditorTest.list(EditorTest.casey)]))
        await sut.model.loadOptions()
        sut.fillValidCreateDraft()
        return sut
    }

    /// An edit editor whose people are loaded (alex), with a changed total so Save is enabled.
    private func makeLoadedEditSUT() async -> BudgetEditorSUT {
        let sut = makeEditEditorSUT()
        sut.listRepo.enqueueFetchLists(.success([EditorTest.list(EditorTest.alex)]))
        await sut.model.loadOptions()
        sut.model.setTotalText("600")
        return sut
    }

    // MARK: Create

    @Test("create: the form is kept, the editor stays open and the banner shows the fixed message")
    func createKeepsFormAndShowsBanner() async {
        let sut = await makeLoadedCreateSUT()
        let draft = sut.model.draft
        sut.manager.enqueueFailure(BudgetError.recipientNotFound)
        sut.listRepo.enqueueFetchLists(.success([EditorTest.list(EditorTest.casey)]))

        let saved = await sut.model.save()

        #expect(saved == nil, "nil keeps the editor open")
        #expect(sut.model.draft == draft, "the user's values are kept")
        #expect(sut.model.banner == InlineErrorBannerState(message: Self.message, actions: [.dismiss]))
        #expect(sut.model.isSaving == false)
        #expect(sut.model.canSave == true, "the user can fix the form and save again")
        #expect(sut.budgets.budgetsByYear.isEmpty)
    }

    @Test("create: the person options are refreshed with a forced lists load, although lists are cached")
    func createRefreshesPeople() async {
        let sut = await makeLoadedCreateSUT()
        #expect(sut.listRepo.fetchListsCount == 1, "precondition: the people were loaded once")
        sut.manager.enqueueFailure(BudgetError.recipientNotFound)
        // Alex can no longer be added: the fresh lists have Casey and Drew.
        sut.listRepo.enqueueFetchLists(.success([EditorTest.list(EditorTest.casey), EditorTest.list(EditorTest.drew)]))

        _ = await sut.model.save()

        #expect(sut.listRepo.fetchListsCount == 2, "a forced load fetches even with cached lists")
        #expect(sut.lists.lists.map(\.id) == ["list-p-c", "list-p-d"])
        #expect(sut.model.picker == .ready([EditorTest.casey, EditorTest.drew]))
        #expect(sut.model.draft.recipients.map(\.recipientId) == ["p-a"], "the chosen person stays in the form")
    }

    @Test("create: the second save after the user removed the person goes through")
    func createRetryAfterFix() async {
        let sut = await makeLoadedCreateSUT()
        sut.manager.enqueueFailure(BudgetError.recipientNotFound)
        sut.listRepo.enqueueFetchLists(.success([EditorTest.list(EditorTest.casey)]))
        _ = await sut.model.save()
        sut.model.removePerson(recipientId: "p-a")
        let stored = EditorTest.stored()
        sut.manager.enqueue(stored)

        let saved = await sut.model.save()

        #expect(saved == stored)
        #expect(sut.model.banner == nil, "a new save clears the banner")
        #expect(sut.manager.callCount == 2)
    }

    // MARK: Edit

    @Test("edit: the form is kept, the editor stays open and the banner shows the fixed message")
    func editKeepsFormAndShowsBanner() async {
        let sut = await makeLoadedEditSUT()
        let draft = sut.model.draft
        sut.manager.enqueueFailure(BudgetError.recipientNotFound)
        sut.listRepo.enqueueFetchLists(.success([EditorTest.list(EditorTest.alex)]))

        let saved = await sut.model.save()

        #expect(saved == nil)
        #expect(sut.model.draft == draft)
        #expect(sut.model.banner == InlineErrorBannerState(message: Self.message, actions: [.dismiss]))
        #expect(sut.model.isSaving == false)
    }

    @Test("edit: the budget is not treated as gone, the cached budget survives")
    func editIsNotGone() async {
        let sut = await makeLoadedEditSUT()
        sut.manager.enqueueList([EditorTest.original()])
        _ = await sut.budgets.loadBudgets(force: true)
        #expect(sut.budgets.budget(for: 2026) == EditorTest.original(), "precondition")
        sut.manager.enqueueFailure(BudgetError.recipientNotFound)
        sut.listRepo.enqueueFetchLists(.success([EditorTest.list(EditorTest.alex)]))

        _ = await sut.model.save()

        #expect(sut.budgets.budget(for: 2026) == EditorTest.original())
        #expect(sut.model.banner?.message != BudgetError.notFound.userMessage)
    }

    @Test("edit: the person options are refreshed with a forced lists load")
    func editRefreshesPeople() async {
        let sut = await makeLoadedEditSUT()
        #expect(sut.listRepo.fetchListsCount == 1, "precondition")
        sut.manager.enqueueFailure(BudgetError.recipientNotFound)
        sut.listRepo.enqueueFetchLists(.success([EditorTest.list(EditorTest.alex), EditorTest.list(EditorTest.casey)]))

        _ = await sut.model.save()

        #expect(sut.listRepo.fetchListsCount == 2)
        // Tommy and Mike are already in the budget, so only the new lists' people are offered.
        #expect(sut.model.picker == .ready([EditorTest.alex, EditorTest.casey]))
    }

    // MARK: Quiet refresh and failed refresh

    @Test("a failing forced refresh does not set the Lists screen's load failure")
    func failingRefreshDoesNotSetListsFailure() async {
        let sut = await makeLoadedCreateSUT()
        sut.manager.enqueueFailure(BudgetError.recipientNotFound)
        sut.listRepo.enqueueFetchLists(.failure(ListError.network))

        _ = await sut.model.save()

        #expect(sut.listRepo.fetchListsCount == 2, "the refresh was attempted")
        #expect(sut.lists.listsLoadFailure == nil)
    }

    @Test("a successful forced refresh does not clear an existing Lists load failure")
    func successfulRefreshKeepsListsFailure() async {
        let sut = makeBudgetEditorSUT()
        sut.listRepo.enqueueFetchLists(.failure(ListError.server))
        await sut.lists.refreshLists()
        #expect(sut.lists.listsLoadFailure == .server, "precondition")
        sut.listRepo.enqueueFetchLists(.success([EditorTest.list(EditorTest.alex), EditorTest.list(EditorTest.casey)]))
        await sut.model.loadOptions()
        sut.fillValidCreateDraft()
        sut.manager.enqueueFailure(BudgetError.recipientNotFound)
        sut.listRepo.enqueueFetchLists(.success([EditorTest.list(EditorTest.casey)]))

        _ = await sut.model.save()

        #expect(sut.model.picker == .ready([EditorTest.casey]), "the refresh itself succeeded")
        #expect(sut.lists.listsLoadFailure == .server)
    }

    @Test("a failing refresh keeps the banner, the draft and the open editor")
    func failingRefreshKeepsBannerAndDraft() async {
        let sut = await makeLoadedCreateSUT()
        let draft = sut.model.draft
        sut.manager.enqueueFailure(BudgetError.recipientNotFound)
        sut.listRepo.enqueueFetchLists(.failure(ListError.network))

        let saved = await sut.model.save()

        #expect(saved == nil)
        #expect(sut.model.draft == draft)
        #expect(sut.model.banner == InlineErrorBannerState(message: Self.message, actions: [.dismiss]))
        #expect(sut.model.isSaving == false)
    }

    @Test("a failing refresh does not turn a failed picker into ready from stale lists")
    func failingRefreshKeepsFailedPicker() async {
        let sut = makeBudgetEditorSUT()
        sut.listRepo.enqueueFetchLists(.failure(ListError.network))
        await sut.model.loadOptions()
        guard case .failed = sut.model.picker else {
            Issue.record("precondition: the picker should be failed, was \(sut.model.picker)")
            return
        }
        let failedPicker = sut.model.picker
        sut.fillValidCreateDraft()
        sut.manager.enqueueFailure(BudgetError.recipientNotFound)
        sut.listRepo.enqueueFetchLists(.failure(ListError.server))

        _ = await sut.model.save()

        #expect(sut.listRepo.fetchListsCount == 2, "the refresh was attempted")
        #expect(sut.model.picker == failedPicker, "a failed refresh must not downgrade a failed picker to ready")
        #expect(sut.model.banner == InlineErrorBannerState(message: Self.message, actions: [.dismiss]))
    }

    @Test("a failing refresh keeps the options that were already loaded")
    func failingRefreshKeepsLoadedOptions() async {
        let sut = await makeLoadedCreateSUT()
        sut.manager.enqueueFailure(BudgetError.recipientNotFound)
        sut.listRepo.enqueueFetchLists(.failure(ListError.network))

        _ = await sut.model.save()

        // Alex is in the draft, so the loaded options minus Alex remain.
        #expect(sut.model.picker == .ready([EditorTest.casey]))
    }

    @Test("a refresh skipped because another refresh is in flight does not claim the options as loaded")
    func skippedRefreshDoesNotClaimLoaded() async {
        let sut = makeBudgetEditorSUT()
        sut.listRepo.enqueueFetchLists(.failure(ListError.network))
        await sut.model.loadOptions()
        let failedPicker = sut.model.picker
        guard case .failed = failedPicker else {
            Issue.record("precondition: the picker should be failed, was \(failedPicker)")
            return
        }
        sut.fillValidCreateDraft()
        // Another refresh is in flight and held, so the editor's own refresh is skipped.
        sut.listRepo.enqueueFetchLists(.success([EditorTest.list(EditorTest.casey)]), held: true)
        let inFlight = Task { await sut.lists.refreshLists() }
        await sut.listRepo.nextHeldCall()
        sut.manager.enqueueFailure(BudgetError.recipientNotFound)

        let saved = await sut.model.save()

        #expect(saved == nil)
        #expect(sut.listRepo.fetchListsCount == 2, "the skipped refresh fetched nothing of its own")
        #expect(sut.model.picker == failedPicker, "a skipped refresh must not turn the picker into ready")
        #expect(sut.model.banner == InlineErrorBannerState(message: Self.message, actions: [.dismiss]))
        sut.listRepo.releaseAll()
        await inFlight.value
    }

    // MARK: Message

    @Test("the message names nobody, whoever is in the draft and the lists")
    func messageNamesNobody() async {
        let sut = await makeLoadedCreateSUT()
        sut.manager.enqueueFailure(BudgetError.recipientNotFound)
        sut.listRepo.enqueueFetchLists(.success([EditorTest.list(EditorTest.casey)]))

        _ = await sut.model.save()

        let shown = sut.model.banner?.message ?? ""
        #expect(shown == Self.message)
        for name in fixtureNames {
            #expect(!shown.contains(name), "the message must not contain \(name)")
        }
    }

    @Test("Dismiss removes the banner and keeps the draft")
    func dismissKeepsDraft() async {
        let sut = await makeLoadedCreateSUT()
        sut.manager.enqueueFailure(BudgetError.recipientNotFound)
        sut.listRepo.enqueueFetchLists(.success([EditorTest.list(EditorTest.casey)]))
        _ = await sut.model.save()
        let draft = sut.model.draft

        sut.model.dismissBanner()

        #expect(sut.model.banner == nil)
        #expect(sut.model.draft == draft)
    }

    // MARK: Contrast

    @Test("update notFound still means gone: the plain not-found banner, and no people refresh")
    func updateNotFoundStaysGone() async {
        let sut = await makeLoadedEditSUT()
        sut.manager.enqueueFailure(BudgetError.notFound)

        let saved = await sut.model.save()

        #expect(saved == nil)
        #expect(BudgetError.notFound.isGone == true)
        #expect(sut.model.banner == InlineErrorBannerState(message: "That budget could not be found.", actions: [.dismiss]))
        #expect(sut.listRepo.fetchListsCount == 1, "only recipientNotFound refreshes the people")
    }

    @Test("other failures do not refresh the people", arguments: [
        BudgetError.network, .server, .forbidden, .validation(message: "fake"), .sumExceedsTotal(message: "fake")
    ])
    func otherFailuresDoNotRefresh(error: BudgetError) async {
        let sut = await makeLoadedCreateSUT()
        sut.manager.enqueueFailure(error)

        _ = await sut.model.save()

        #expect(sut.listRepo.fetchListsCount == 1)
        #expect(sut.model.banner != nil)
    }
}
