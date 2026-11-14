//
//  BudgetEditorModelListsLoadTests.swift
//  ChristmasTrackerTests
//
//  UX1a Story U2 (I5a review findings D and E):
//   - D: opening the budget editor while a lists load is already in flight shows the loading state and
//     then the people; the picker never shows an empty list ("Nobody to add yet") because the editor's
//     loadLists returned at once. The editor waits for the in-flight load and does not fetch again.
//   - E: the editor's own lists load uses loadLists(reportingFailure: false); a failure goes to the
//     picker state only and is stored in no ListService property that the Lists screen reads.
//
//  Determinism: the in-flight load is held by the gated repository; the editor task is created before
//  the release and the test does not suspend in between (see ListServiceLoadListsWaitTests). No sleeps,
//  no yield loops.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("BudgetEditorModel lists load Tests", .timeLimit(.minutes(1)))
@MainActor
struct BudgetEditorModelListsLoadTests {

    // MARK: Finding D

    @Test("opened while a lists load is in flight, the editor shows loading, then the people")
    func openedDuringInFlightLoadShowsLoadingThenPeople() async {
        let sut = makeBudgetEditorSUT()
        sut.listRepo.enqueueFetchLists(.success([EditorTest.list(EditorTest.alex)]), held: true)
        let dashboardLoad = Task { @MainActor in await sut.lists.loadLists() }
        await sut.listRepo.nextHeldCall()
        #expect(sut.lists.isLoadingLists == true, "precondition: the lists are still loading")

        let open = Task { @MainActor in await sut.model.loadOptions() }
        // F2 (UX1a U2 review): the old `== .loading` assertion was vacuous (the picker starts as
        // .loading before the open Task even runs) and is replaced. There is no handshake for "the
        // open Task has reached its wait", so the claim "shows loading mid-wait" cannot be tested
        // deterministically and is dropped. What IS testable while the fetch is held: the picker is
        // never the empty ready state. The final assertions below carry the real check.
        #expect(sut.model.picker != .ready([]), "never 'Nobody to add yet' while the lists are still loading")
        sut.listRepo.releaseAll()
        await dashboardLoad.value
        await open.value

        #expect(sut.model.picker == .ready([EditorTest.alex]), "the people, never an empty 'Nobody to add yet'")
        #expect(sut.listRepo.fetchListsCount == 1, "the editor waited for the in-flight load and fetched nothing")
        #expect(sut.lists.lists.map(\.id) == ["list-p-a"])
    }

    @Test("opened while a lists load is in flight, a total-only budget can be saved meanwhile")
    func saveWorksWhileWaiting() async {
        let sut = makeBudgetEditorSUT()
        sut.listRepo.enqueueFetchLists(.success([EditorTest.list(EditorTest.alex)]), held: true)
        let dashboardLoad = Task { @MainActor in await sut.lists.loadLists() }
        await sut.listRepo.nextHeldCall()

        let open = Task { @MainActor in await sut.model.loadOptions() }
        sut.model.setTotalText("300")
        #expect(sut.model.canSave == true, "a total-only budget does not wait for the picker")
        #expect(sut.model.picker != .ready([]), "the picker is not the empty ready state while the fetch is held")

        sut.listRepo.releaseAll()
        await dashboardLoad.value
        await open.value
        #expect(sut.model.picker == .ready([EditorTest.alex]))
    }

    // F1 (UX1a U2 review): a cancelled in-flight load must not leave the editor on ready([]).
    @Test("opened while the in-flight dashboard load is CANCELLED, the editor still ends with the people")
    func openedDuringCancelledInFlightLoadShowsPeople() async {
        let sut = makeBudgetEditorSUT()
        sut.listRepo.honorsCancellation = true
        sut.listRepo.enqueueFetchLists(.success([EditorTest.list(EditorTest.casey)]), held: true)   // cancelled
        sut.listRepo.enqueueFetchLists(.success([EditorTest.list(EditorTest.alex)]))                 // the waiter's own load
        let dashboardLoad = Task { @MainActor in await sut.lists.loadLists() }
        await sut.listRepo.nextHeldCall()

        let open = Task { @MainActor in await sut.model.loadOptions() }
        dashboardLoad.cancel()
        await dashboardLoad.value
        await open.value

        #expect(sut.model.picker == .ready([EditorTest.alex]), "the people, never 'Nobody to add yet'")
        #expect(sut.listRepo.fetchListsCount == 2, "the waiter started its own load once")
    }

    @Test("opened while the in-flight lists load FAILS, the editor shows the failed picker and fetches nothing")
    func openedDuringInFlightFailure() async {
        let sut = makeBudgetEditorSUT()
        sut.listRepo.enqueueFetchLists(.failure(ListError.network), held: true)
        let dashboardLoad = Task { @MainActor in await sut.lists.loadLists() }
        await sut.listRepo.nextHeldCall()

        let open = Task { @MainActor in await sut.model.loadOptions() }
        sut.listRepo.releaseAll()
        await dashboardLoad.value
        await open.value

        #expect(sut.model.picker == .failed(message: ListError.network.userMessage))
        #expect(sut.listRepo.fetchListsCount == 1)
    }

    @Test("with the merged spend people the editor opened during a load still lists them with the people")
    func openedDuringLoadMergesSpend() async {
        let spend = [BudgetFixtures.spend(id: "p-c", name: "Casey Spender", spent: "40", items: 1)]
        let sut = makeBudgetEditorSUT(spend: spend)
        sut.listRepo.enqueueFetchLists(.success([EditorTest.list(EditorTest.alex)]), held: true)
        let dashboardLoad = Task { @MainActor in await sut.lists.loadLists() }
        await sut.listRepo.nextHeldCall()

        let open = Task { @MainActor in await sut.model.loadOptions() }
        sut.listRepo.releaseAll()
        await dashboardLoad.value
        await open.value

        #expect(sut.model.picker == .ready([EditorTest.alex, EditorTest.casey]))
    }

    // MARK: Finding E

    @Test("the editor's failed lists load is stored in no ListService property")
    func editorFailureIsStoredNowhere() async {
        let sut = makeBudgetEditorSUT()
        sut.listRepo.enqueueFetchLists(.failure(ListError.network))

        await sut.model.loadOptions()

        #expect(sut.model.picker == .failed(message: ListError.network.userMessage))
        #expect(sut.lists.listsLoadFailure == nil, "the Lists screen must never see the editor's failure")
        #expect(sut.lists.detailLoadFailure == nil)
    }

    @Test("the editor's failure is stored nowhere for every kind of lists failure", arguments: [
        ListError.server, .rateLimited(retryAfter: 3), .invalidResponse, .forbidden
    ])
    func editorFailureIsStoredNowhereForEveryKind(error: ListError) async {
        let sut = makeBudgetEditorSUT()
        sut.listRepo.enqueueFetchLists(.failure(error))

        await sut.model.loadOptions()

        #expect(sut.model.picker == .failed(message: error.userMessage))
        #expect(sut.lists.listsLoadFailure == nil)
        #expect(sut.lists.detailLoadFailure == nil)
    }

    @Test("a lists failure the dashboard holds survives the editor's failed load")
    func dashboardFailureSurvivesEditorFailure() async {
        let sut = makeBudgetEditorSUT()
        sut.listRepo.enqueueFetchLists(.failure(ListError.server))
        await sut.lists.refreshLists()
        #expect(sut.lists.listsLoadFailure == .server, "precondition")
        sut.listRepo.enqueueFetchLists(.failure(ListError.network))

        await sut.model.loadOptions()

        #expect(sut.model.picker == .failed(message: ListError.network.userMessage))
        #expect(sut.lists.listsLoadFailure == .server, "neither replaced nor cleared")
    }

    @Test("a lists failure the dashboard holds is not cleared by the editor's successful load")
    func dashboardFailureSurvivesEditorSuccess() async {
        let sut = makeBudgetEditorSUT()
        sut.listRepo.enqueueFetchLists(.failure(ListError.server))
        await sut.lists.refreshLists()
        sut.listRepo.enqueueFetchLists(.success([EditorTest.list(EditorTest.alex)]))

        await sut.model.loadOptions()

        #expect(sut.model.picker == .ready([EditorTest.alex]))
        #expect(sut.lists.listsLoadFailure == .server)
    }

    @Test("the dashboard's own load right after a failed editor load starts clean")
    func dashboardLoadAfterEditorFailureIsClean() async {
        let sut = makeBudgetEditorSUT()
        sut.listRepo.enqueueFetchLists(.failure(ListError.network))
        await sut.model.loadOptions()
        sut.listRepo.enqueueFetchLists(.success([EditorTest.list(EditorTest.alex)]))

        let failure = await sut.lists.loadLists()

        #expect(failure == nil)
        #expect(sut.lists.listsLoadFailure == nil)
        #expect(sut.lists.lists.map(\.id) == ["list-p-a"])
    }
}
