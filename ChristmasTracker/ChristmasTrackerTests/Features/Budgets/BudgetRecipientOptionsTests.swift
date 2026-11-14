//
//  BudgetRecipientOptionsTests.swift
//  ChristmasTrackerTests
//
//  I5a Story A: BudgetRecipientOptions.build and unused.
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
        existing: [RecipientBudget] = [],
        spend: [RecipientSpend] = []
    ) -> [BudgetRecipientOption] {
        BudgetRecipientOptions.build(lists: lists, existing: existing, spend: spend)
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

    // MARK: - Existing and spend

    @Test func existingAllocationsAreKeptEvenWithoutAList() {
        let existing = [BudgetFixtures.recipientBudget(id: "r9", name: "Jane", max: "100", spent: "0")]
        #expect(build(existing: existing) == [option("r9", "Jane")])
    }

    @Test func spendRecipientsAreMerged() {
        let spend = [BudgetFixtures.spend(id: "r8", name: "Mike", spent: "12.00", items: 1)]
        #expect(build(spend: spend) == [option("r8", "Mike")])
    }

    @Test func allThreeSourcesAreMerged() {
        let lists = [BudgetFixtures.list(id: "l1", recipientId: "r1", recipientName: "Tommy", canPurchase: true)]
        let existing = [BudgetFixtures.recipientBudget(id: "r2", name: "Mike", max: "100", spent: "0")]
        let spend = [BudgetFixtures.spend(id: "r3", name: "John", spent: "5", items: 1)]
        let result = build(lists: lists, existing: existing, spend: spend)
        #expect(result == [option("r3", "John"), option("r2", "Mike"), option("r1", "Tommy")])
    }

    // MARK: - De-duplication

    @Test func sameRecipientInTwoListsAppearsOnce() {
        let lists = [
            BudgetFixtures.list(id: "l1", recipientId: "r1", recipientName: "Tommy", canPurchase: true),
            BudgetFixtures.list(id: "l2", recipientId: "r1", recipientName: "Tommy", canPurchase: true)
        ]
        #expect(build(lists: lists) == [option("r1", "Tommy")])
    }

    @Test func sameRecipientAcrossAllSourcesAppearsOnce() {
        let lists = [BudgetFixtures.list(id: "l1", recipientId: "r1", recipientName: "Tommy", canPurchase: true)]
        let existing = [BudgetFixtures.recipientBudget(id: "r1", name: "Tommy", max: "100", spent: "0")]
        let spend = [BudgetFixtures.spend(id: "r1", name: "Tommy", spent: "5", items: 1)]
        #expect(build(lists: lists, existing: existing, spend: spend) == [option("r1", "Tommy")])
    }

    // MARK: - Name selection

    @Test func listNameWinsOverExistingAndSpend() {
        let lists = [BudgetFixtures.list(id: "l1", recipientId: "r1", recipientName: "From List", canPurchase: true)]
        let existing = [BudgetFixtures.recipientBudget(id: "r1", name: "From Existing", max: "1", spent: "0")]
        let spend = [BudgetFixtures.spend(id: "r1", name: "From Spend", spent: "1", items: 1)]
        #expect(build(lists: lists, existing: existing, spend: spend) == [option("r1", "From List")])
    }

    @Test func existingNameWinsOverSpendWhenNoList() {
        let existing = [BudgetFixtures.recipientBudget(id: "r1", name: "From Existing", max: "1", spent: "0")]
        let spend = [BudgetFixtures.spend(id: "r1", name: "From Spend", spent: "1", items: 1)]
        #expect(build(existing: existing, spend: spend) == [option("r1", "From Existing")])
    }

    @Test func blankListNameFallsThroughToExisting() {
        let lists = [BudgetFixtures.list(id: "l1", recipientId: "r1", recipientName: "   ", canPurchase: true)]
        let existing = [BudgetFixtures.recipientBudget(id: "r1", name: "From Existing", max: "1", spent: "0")]
        let spend = [BudgetFixtures.spend(id: "r1", name: "From Spend", spent: "1", items: 1)]
        #expect(build(lists: lists, existing: existing, spend: spend) == [option("r1", "From Existing")])
    }

    @Test func blankListAndExistingNamesFallThroughToSpend() {
        let lists = [BudgetFixtures.list(id: "l1", recipientId: "r1", recipientName: "", canPurchase: true)]
        let existing = [BudgetFixtures.recipientBudget(id: "r1", name: " \n", max: "1", spent: "0")]
        let spend = [BudgetFixtures.spend(id: "r1", name: "From Spend", spent: "1", items: 1)]
        #expect(build(lists: lists, existing: existing, spend: spend) == [option("r1", "From Spend")])
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
        let spend = [
            BudgetFixtures.spend(id: "a", name: "carl", spent: "1", items: 1),
            BudgetFixtures.spend(id: "b", name: "Alice", spent: "1", items: 1),
            BudgetFixtures.spend(id: "c", name: "bob", spent: "1", items: 1)
        ]
        #expect(build(spend: spend).map(\.displayName) == ["Alice", "bob", "carl"])
    }

    @Test func equalNamesAreTiedById() {
        let spend = [
            BudgetFixtures.spend(id: "b", name: "Sam", spent: "1", items: 1),
            BudgetFixtures.spend(id: "a", name: "Sam", spent: "1", items: 1),
            BudgetFixtures.spend(id: "c", name: "sam", spent: "1", items: 1)
        ]
        #expect(build(spend: spend).map(\.id) == ["a", "b", "c"])
    }

    @Test func emptyInputsGiveNoOptions() {
        #expect(build().isEmpty)
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
