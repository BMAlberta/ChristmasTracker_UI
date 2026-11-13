//
//  BudgetRequestBuilderTests.swift
//  ChristmasTrackerTests
//
//  I5a Story A: create, edit-diff and duplicate request building.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("BudgetRequestBuilder")
struct BudgetRequestBuilderTests {

    private let locale = BudgetFixtures.enUS

    private func dec(_ text: String) -> Decimal { BudgetFixtures.dec(text) }

    private func update(_ draft: BudgetDraft) -> UpdateBudgetRequest? {
        BudgetRequestBuilder.update(draft: draft, original: BudgetFixtures.originalBudget(), locale: locale)
    }

    // MARK: - Create

    @Test func createWithRecipientsKeepsDraftOrder() throws {
        let draft = BudgetFixtures.draft(
            year: 2027,
            total: "500.00",
            limits: [(id: "r2", limit: "250"), (id: "r1", limit: "200.50")]
        )
        let request = try #require(BudgetRequestBuilder.create(draft: draft, locale: locale))
        #expect(request.year == 2027)
        #expect(request.totalBudget == dec("500"))
        #expect(request.recipients == [
            BudgetLimit(recipientId: "r2", maxSpend: dec("250")),
            BudgetLimit(recipientId: "r1", maxSpend: dec("200.50"))
        ])
    }

    @Test func createWithoutRecipientsSendsAnEmptyArray() throws {
        let request = try #require(BudgetRequestBuilder.create(draft: BudgetFixtures.draft(total: "0"), locale: locale))
        #expect(request.year == 2026)
        #expect(request.totalBudget == 0)
        #expect(request.recipients.isEmpty)
    }

    @Test func createReturnsNilForInvalidTotal() {
        #expect(BudgetRequestBuilder.create(draft: BudgetFixtures.draft(total: "abc"), locale: locale) == nil)
    }

    @Test func createReturnsNilForInvalidLimit() {
        let draft = BudgetFixtures.draft(total: "100", limits: [(id: "r1", limit: "x")])
        #expect(BudgetRequestBuilder.create(draft: draft, locale: locale) == nil)
    }

    @Test func createReturnsNilWhenLimitsExceedTotal() {
        let draft = BudgetFixtures.draft(total: "100", limits: [(id: "r1", limit: "100.01")])
        #expect(BudgetRequestBuilder.create(draft: draft, locale: locale) == nil)
    }

    @Test func createReturnsNilForDuplicatePerson() {
        let draft = BudgetFixtures.draft(total: "100", limits: [(id: "r1", limit: "10"), (id: "r1", limit: "20")])
        #expect(BudgetRequestBuilder.create(draft: draft, locale: locale) == nil)
    }

    // MARK: - Update diff

    @Test func updateNothingChangedReturnsNil() {
        #expect(update(BudgetFixtures.matchingDraft()) == nil)
    }

    @Test func updateEquivalentTextIsNotAChange() {
        let draft = BudgetFixtures.draft(total: "500", limits: [(id: "r1", limit: "200"), (id: "r2", limit: "250.0")])
        #expect(update(draft) == nil)
    }

    @Test func updateOnlyTotalLeavesRecipientsNil() throws {
        let draft = BudgetFixtures.draft(total: "600", limits: [(id: "r1", limit: "200"), (id: "r2", limit: "250")])
        let request = try #require(update(draft))
        #expect(request.year == 2026)
        #expect(request.totalBudget == dec("600"))
        #expect(request.recipients == nil)
    }

    @Test func updateOnlyALimitSendsTheFullListAndNoTotal() throws {
        let draft = BudgetFixtures.draft(total: "500", limits: [(id: "r1", limit: "210"), (id: "r2", limit: "250")])
        let request = try #require(update(draft))
        #expect(request.totalBudget == nil)
        #expect(request.recipients == [
            BudgetLimit(recipientId: "r1", maxSpend: dec("210")),
            BudgetLimit(recipientId: "r2", maxSpend: dec("250"))
        ])
    }

    @Test func updatePersonAddedSendsTheFullList() throws {
        let draft = BudgetFixtures.draft(
            total: "500",
            limits: [(id: "r1", limit: "200"), (id: "r2", limit: "250"), (id: "r3", limit: "10")]
        )
        let request = try #require(update(draft))
        #expect(request.totalBudget == nil)
        #expect(request.recipients == [
            BudgetLimit(recipientId: "r1", maxSpend: dec("200")),
            BudgetLimit(recipientId: "r2", maxSpend: dec("250")),
            BudgetLimit(recipientId: "r3", maxSpend: dec("10"))
        ])
    }

    @Test func updatePersonRemovedSendsTheShorterList() throws {
        let draft = BudgetFixtures.draft(total: "500", limits: [(id: "r1", limit: "200")])
        let request = try #require(update(draft))
        #expect(request.totalBudget == nil)
        #expect(request.recipients == [BudgetLimit(recipientId: "r1", maxSpend: dec("200"))])
    }

    @Test func updateAllPeopleRemovedSendsAnEmptyList() throws {
        let draft = BudgetFixtures.draft(total: "500")
        let request = try #require(update(draft))
        #expect(request.totalBudget == nil)
        #expect(request.recipients == [])
    }

    @Test func updateReorderOnlyIsNoChange() {
        let draft = BudgetFixtures.draft(total: "500", limits: [(id: "r2", limit: "250"), (id: "r1", limit: "200")])
        #expect(update(draft) == nil)
    }

    @Test func updateTotalAndLimitsBothChanged() throws {
        let draft = BudgetFixtures.draft(total: "700", limits: [(id: "r2", limit: "300"), (id: "r1", limit: "200")])
        let request = try #require(update(draft))
        #expect(request.year == 2026)
        #expect(request.totalBudget == dec("700"))
        #expect(request.recipients == [
            BudgetLimit(recipientId: "r2", maxSpend: dec("300")),
            BudgetLimit(recipientId: "r1", maxSpend: dec("200"))
        ])
    }

    @Test func updateYearComesFromTheOriginal() throws {
        let draft = BudgetFixtures.draft(year: 2031, total: "600", limits: [(id: "r1", limit: "200"), (id: "r2", limit: "250")])
        let request = try #require(update(draft))
        #expect(request.year == 2026)
    }

    @Test func updateReturnsNilWhenInvalid() {
        let overTotal = BudgetFixtures.draft(total: "100", limits: [(id: "r1", limit: "200"), (id: "r2", limit: "250")])
        #expect(update(overTotal) == nil)
        let badTotal = BudgetFixtures.draft(total: "abc", limits: [(id: "r1", limit: "200"), (id: "r2", limit: "250")])
        #expect(update(badTotal) == nil)
    }

    // MARK: - Duplicate

    @Test func duplicateCarriesBothYears() {
        let request = BudgetRequestBuilder.duplicate(fromYear: 2026, toYear: 2027)
        #expect(request.fromYear == 2026)
        #expect(request.toYear == 2027)
    }

    // MARK: - hasChanges

    @Test func hasChangesIsFalseForAMatchingDraft() {
        let result = BudgetRequestBuilder.hasChanges(
            draft: BudgetFixtures.matchingDraft(), original: BudgetFixtures.originalBudget(), locale: locale
        )
        #expect(!result)
    }

    @Test func hasChangesIsFalseForReorderOnly() {
        let draft = BudgetFixtures.draft(total: "500", limits: [(id: "r2", limit: "250"), (id: "r1", limit: "200")])
        #expect(!BudgetRequestBuilder.hasChanges(draft: draft, original: BudgetFixtures.originalBudget(), locale: locale))
    }

    @Test func hasChangesIsTrueForTotalLimitAddAndRemove() {
        let original = BudgetFixtures.originalBudget()
        let drafts = [
            BudgetFixtures.draft(total: "501", limits: [(id: "r1", limit: "200"), (id: "r2", limit: "250")]),
            BudgetFixtures.draft(total: "500", limits: [(id: "r1", limit: "201"), (id: "r2", limit: "250")]),
            BudgetFixtures.draft(
                total: "500",
                limits: [(id: "r1", limit: "200"), (id: "r2", limit: "250"), (id: "r3", limit: "1")]
            ),
            BudgetFixtures.draft(total: "500", limits: [(id: "r1", limit: "200")])
        ]
        for draft in drafts {
            #expect(BudgetRequestBuilder.hasChanges(draft: draft, original: original, locale: locale))
        }
    }
}
