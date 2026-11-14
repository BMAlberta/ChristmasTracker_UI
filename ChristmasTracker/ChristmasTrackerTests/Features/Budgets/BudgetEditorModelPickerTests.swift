//
//  BudgetEditorModelPickerTests.swift
//  ChristmasTrackerTests
//
//  I5a Story C: the person picker of BudgetEditorModel. The lists are loaded cache-first through the
//  ListService when the editor opens: loading while they load, ready with the options (people the user
//  can buy for, people already in the budget, people in the year's spend; used people removed), failed
//  with the service's message when they cannot be loaded. In every state a total-only budget can be saved.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("BudgetEditorModel picker Tests", .timeLimit(.minutes(1)))
@MainActor
struct BudgetEditorModelPickerTests {

    // MARK: Loading

    @Test("the picker is loading while the lists load, then ready; Save of a total-only budget works meanwhile")
    func loadingThenReady() async {
        let sut = makeBudgetEditorSUT()
        sut.listRepo.enqueueFetchLists(.success([EditorTest.list(EditorTest.alex)]), held: true)

        let load = Task { @MainActor in await sut.model.loadOptions() }
        await sut.listRepo.nextHeldCall()

        #expect(sut.model.picker == .loading)
        sut.model.setTotalText("300")
        #expect(sut.model.canSave == true, "a total-only budget does not wait for the picker")
        #expect(sut.model.picker == .loading)

        sut.listRepo.releaseAll()
        await load.value
        #expect(sut.model.picker == .ready([EditorTest.alex]))
    }

    // MARK: Ready

    @Test("ready lists the people the user can buy for, sorted by name, without blind own lists")
    func readyExcludesBlindOwnLists() async {
        let sut = makeBudgetEditorSUT()
        let blind = EditorTest.list(EditorTest.drew, canPurchase: false)
        sut.listRepo.enqueueFetchLists(.success([
            EditorTest.list(EditorTest.casey), blind, EditorTest.list(EditorTest.alex)
        ]))

        await sut.model.loadOptions()

        #expect(sut.model.picker == .ready([EditorTest.alex, EditorTest.casey]))
    }

    @Test("ready merges the year's spend people with the people from the lists, without duplicates")
    func readyMergesSpend() async {
        let spend = [
            BudgetFixtures.spend(id: "p-c", name: "Casey Spender", spent: "40", items: 1),
            BudgetFixtures.spend(id: "p-a", name: "Alex Giftee", spent: "10", items: 1)
        ]
        let sut = makeBudgetEditorSUT(spend: spend)
        sut.listRepo.enqueueFetchLists(.success([EditorTest.list(EditorTest.alex), EditorTest.list(EditorTest.drew)]))

        await sut.model.loadOptions()

        #expect(sut.model.picker == .ready([EditorTest.alex, EditorTest.casey, EditorTest.drew]))
    }

    @Test("ready offers a person of the year's spend even when no list says the user can buy for them")
    func readyKeepsSpendOnlyPerson() async {
        let spend = [BudgetFixtures.spend(id: "p-c", name: "Casey Spender", spent: "40", items: 1)]
        let sut = makeBudgetEditorSUT(spend: spend)
        sut.listRepo.enqueueFetchLists(.success([EditorTest.list(EditorTest.drew, canPurchase: false)]))

        await sut.model.loadOptions()

        #expect(sut.model.picker == .ready([EditorTest.casey]))
    }

    @Test("ready for a user with no lists and no spend is an empty list, not a failure")
    func readyEmpty() async {
        let sut = makeBudgetEditorSUT()
        sut.listRepo.enqueueFetchLists(.success([]))

        await sut.model.loadOptions()

        #expect(sut.model.picker == .ready([]))
    }

    @Test("people already in the draft are removed from the options, and come back when removed")
    func usedPeopleAreRemoved() async {
        let sut = makeBudgetEditorSUT()
        sut.listRepo.enqueueFetchLists(.success([EditorTest.list(EditorTest.alex), EditorTest.list(EditorTest.casey)]))
        await sut.model.loadOptions()

        sut.model.addPerson(EditorTest.alex)
        #expect(sut.model.picker == .ready([EditorTest.casey]))

        sut.model.removePerson(recipientId: "p-a")
        #expect(sut.model.picker == .ready([EditorTest.alex, EditorTest.casey]))
    }

    @Test("edit: people already in the budget are not offered, a removed one is offered again by name")
    func editExistingPeopleMerge() async {
        let sut = makeEditEditorSUT()
        sut.listRepo.enqueueFetchLists(.success([EditorTest.list(EditorTest.alex)]))
        await sut.model.loadOptions()
        #expect(sut.model.picker == .ready([EditorTest.alex]), "Tommy and Mike are already in the budget")

        sut.model.removePerson(recipientId: "r2")

        let mike = BudgetRecipientOption(id: "r2", displayName: "Mike")
        #expect(sut.model.picker == .ready([EditorTest.alex, mike]))
    }

    @Test("the lists load cache-first: lists already in the service are not fetched again")
    func cacheFirst() async {
        let sut = makeBudgetEditorSUT()
        sut.listRepo.enqueueFetchLists(.success([EditorTest.list(EditorTest.alex)]))
        await sut.lists.loadLists()
        #expect(sut.listRepo.fetchListsCount == 1)

        await sut.model.loadOptions()

        #expect(sut.listRepo.fetchListsCount == 1)
        #expect(sut.model.picker == .ready([EditorTest.alex]))
    }

    // MARK: Failed

    @Test("the picker fails with the list service's message when the lists cannot be loaded")
    func failedState() async {
        let sut = makeBudgetEditorSUT()
        sut.listRepo.enqueueFetchLists(.failure(ListError.network))

        await sut.model.loadOptions()

        #expect(sut.model.picker == .failed(message: ListError.network.userMessage))
    }

    @Test("a failed picker does not block Save of a total-only budget")
    func failedDoesNotBlockSave() async {
        let sut = makeBudgetEditorSUT()
        sut.listRepo.enqueueFetchLists(.failure(ListError.server))
        await sut.model.loadOptions()
        sut.model.setTotalText("300")

        #expect(sut.model.canSave == true)

        sut.manager.enqueue(EditorTest.stored(total: "300"))
        let saved = await sut.model.save()
        #expect(saved != nil)
        #expect(sut.manager.calls == [.create(CreateBudgetRequest(year: 2026, totalBudget: BudgetFixtures.dec("300"), recipients: []))])
    }
}
