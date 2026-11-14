//
//  BudgetRecipientOptionsTests.swift
//  ChristmasTrackerTests
//
//  I5a Story A, I5b Story B: BudgetRecipientOptions.build and unused. The candidate rule is exactly the
//  recipients of the lists where canPurchase is true (the user's own blind lists excluded) plus the
//  recipients already in the budget. There is no spend group.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("BudgetRecipientOptions")
struct BudgetRecipientOptionsTests {

    private func option(_ id: String, _ name: String) -> BudgetRecipientOption {
        BudgetRecipientOption(id: id, displayName: name)
    }

    private func build(
        lists: [GiftList] = [],
        existing: [RecipientBudget] = []
    ) -> [BudgetRecipientOption] {
        BudgetRecipientOptions.build(lists: lists, existing: existing)
    }

    // MARK: - Lists

    @Test func listWithCanPurchaseTrueContributesItsRecipient() {
        let lists = [BudgetFixtures.list(id: "l1", recipientId: "r1", recipientName: "Tommy", canPurchase: true)]
        #expect(build(lists: lists) == [option("r1", "Tommy")])
    }

    @Test func listWithCanPurchaseFalseContributesNothing() {
        let lists = [BudgetFixtures.list(id: "l1", recipientId: "r1", recipientName: "Tommy", canPurchase: false)]
        #expect(build(lists: lists).isEmpty)
    }

    @Test func ownBlindListIsExcluded() {
        let lists = [
            BudgetFixtures.list(
                id: "self", recipientId: "me", recipientName: "Jane", canPurchase: false, isRecipient: true
            ),
            BudgetFixtures.list(id: "l1", recipientId: "r1", recipientName: "Tommy", canPurchase: true)
        ]
        #expect(build(lists: lists) == [option("r1", "Tommy")])
    }

    @Test func mixedListsKeepOnlyPurchasableRecipients() {
        let lists = [
            BudgetFixtures.list(id: "l1", recipientId: "r1", recipientName: "Tommy", canPurchase: true),
            BudgetFixtures.list(id: "l2", recipientId: "r2", recipientName: "Mike", canPurchase: false),
            BudgetFixtures.list(id: "l3", recipientId: "r3", recipientName: "John", canPurchase: true)
        ]
        #expect(build(lists: lists).map(\.id) == ["r3", "r1"])
    }

    // MARK: - Existing allocations alone

    @Test func existingAllocationsAreKeptEvenWithoutAList() {
        let existing = [BudgetFixtures.recipientBudget(id: "r9", name: "Jane", max: "100", spent: "0")]
        #expect(build(existing: existing) == [option("r9", "Jane")])
    }

    @Test func existingAllocationsAloneKeepEveryRecipient() {
        let existing = [
            BudgetFixtures.recipientBudget(id: "r2", name: "Mike", max: "100", spent: "0"),
            BudgetFixtures.recipientBudget(id: "r1", name: "Tommy", max: "100", spent: "0")
        ]
        #expect(build(existing: existing) == [option("r2", "Mike"), option("r1", "Tommy")])
    }

    // MARK: - Both groups together

    @Test func listsAndExistingAreMerged() {
        let lists = [BudgetFixtures.list(id: "l1", recipientId: "r1", recipientName: "Tommy", canPurchase: true)]
        let existing = [BudgetFixtures.recipientBudget(id: "r2", name: "Mike", max: "100", spent: "0")]
        #expect(build(lists: lists, existing: existing) == [option("r2", "Mike"), option("r1", "Tommy")])
    }

    @Test func existingAllocationIsKeptEvenWhenItsListIsNotPurchasable() {
        let lists = [BudgetFixtures.list(id: "l1", recipientId: "r1", recipientName: "Tommy", canPurchase: false)]
        let existing = [BudgetFixtures.recipientBudget(id: "r1", name: "Tommy", max: "100", spent: "0")]
        #expect(build(lists: lists, existing: existing) == [option("r1", "Tommy")])
    }

    // MARK: - No group (empty)

    @Test func emptyInputsGiveNoOptions() {
        #expect(build().isEmpty)
    }

    @Test func nothingPurchasableAndNothingExistingGivesNoOptions() {
        let lists = [
            BudgetFixtures.list(id: "l1", recipientId: "r1", recipientName: "Tommy", canPurchase: false),
            BudgetFixtures.list(
                id: "self", recipientId: "me", recipientName: "Jane", canPurchase: false, isRecipient: true
            )
        ]
        #expect(build(lists: lists, existing: []).isEmpty)
    }

    // MARK: - De-duplication

    @Test func sameRecipientInTwoListsAppearsOnce() {
        let lists = [
            BudgetFixtures.list(id: "l1", recipientId: "r1", recipientName: "Tommy", canPurchase: true),
            BudgetFixtures.list(id: "l2", recipientId: "r1", recipientName: "Tommy", canPurchase: true)
        ]
        #expect(build(lists: lists) == [option("r1", "Tommy")])
    }

    @Test func sameRecipientAcrossBothGroupsAppearsOnce() {
        let lists = [BudgetFixtures.list(id: "l1", recipientId: "r1", recipientName: "Tommy", canPurchase: true)]
        let existing = [BudgetFixtures.recipientBudget(id: "r1", name: "Tommy", max: "100", spent: "0")]
        #expect(build(lists: lists, existing: existing) == [option("r1", "Tommy")])
    }

    // MARK: - Name selection

    @Test func listNameWinsOverExisting() {
        let lists = [BudgetFixtures.list(id: "l1", recipientId: "r1", recipientName: "From List", canPurchase: true)]
        let existing = [BudgetFixtures.recipientBudget(id: "r1", name: "From Existing", max: "1", spent: "0")]
        #expect(build(lists: lists, existing: existing) == [option("r1", "From List")])
    }

    @Test func blankListNameFallsThroughToExisting() {
        let lists = [BudgetFixtures.list(id: "l1", recipientId: "r1", recipientName: "   ", canPurchase: true)]
        let existing = [BudgetFixtures.recipientBudget(id: "r1", name: "From Existing", max: "1", spent: "0")]
        #expect(build(lists: lists, existing: existing) == [option("r1", "From Existing")])
    }

    @Test func firstNonBlankListNameWinsAcrossLists() {
        let lists = [
            BudgetFixtures.list(id: "l1", recipientId: "r1", recipientName: "", canPurchase: true),
            BudgetFixtures.list(id: "l2", recipientId: "r1", recipientName: "Second", canPurchase: true),
            BudgetFixtures.list(id: "l3", recipientId: "r1", recipientName: "Third", canPurchase: true)
        ]
        #expect(build(lists: lists) == [option("r1", "Second")])
    }

    // MARK: - Sorting

    @Test func sortingIsCaseInsensitive() {
        let existing = [
            BudgetFixtures.recipientBudget(id: "a", name: "carl", max: "1", spent: "0"),
            BudgetFixtures.recipientBudget(id: "b", name: "Alice", max: "1", spent: "0"),
            BudgetFixtures.recipientBudget(id: "c", name: "bob", max: "1", spent: "0")
        ]
        #expect(build(existing: existing).map(\.displayName) == ["Alice", "bob", "carl"])
    }

    @Test func equalNamesAreTiedById() {
        let existing = [
            BudgetFixtures.recipientBudget(id: "b", name: "Sam", max: "1", spent: "0"),
            BudgetFixtures.recipientBudget(id: "a", name: "Sam", max: "1", spent: "0"),
            BudgetFixtures.recipientBudget(id: "c", name: "sam", max: "1", spent: "0")
        ]
        #expect(build(existing: existing).map(\.id) == ["a", "b", "c"])
    }

    // MARK: - unused

    @Test func unusedRemovesPeopleAlreadyInTheDraftAndKeepsOrder() {
        let options = [option("r1", "Alice"), option("r2", "Bob"), option("r3", "Carl")]
        let draft = BudgetFixtures.draft(total: "100", limits: [(id: "r2", limit: "10")])
        #expect(BudgetRecipientOptions.unused(options, in: draft) == [option("r1", "Alice"), option("r3", "Carl")])
    }

    @Test func unusedKeepsEverythingForAnEmptyDraft() {
        let options = [option("r1", "Alice"), option("r2", "Bob")]
        #expect(BudgetRecipientOptions.unused(options, in: BudgetFixtures.draft(total: "0")) == options)
    }

    @Test func unusedIsEmptyWhenEveryoneIsUsed() {
        let options = [option("r1", "Alice"), option("r2", "Bob")]
        let draft = BudgetFixtures.draft(total: "100", limits: [(id: "r1", limit: "1"), (id: "r2", limit: "1")])
        #expect(BudgetRecipientOptions.unused(options, in: draft).isEmpty)
    }
}
