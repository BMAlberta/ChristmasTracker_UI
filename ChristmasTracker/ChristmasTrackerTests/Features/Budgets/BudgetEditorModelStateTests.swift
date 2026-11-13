//
//  BudgetEditorModelStateTests.swift
//  ChristmasTrackerTests
//
//  I5a Story C: the pure-looking state of BudgetEditorModel: the create and edit defaults, the editing
//  methods, the validation and the summary line, and the canSave rules. No repository is called by any
//  test in this file.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("BudgetEditorModel state Tests", .timeLimit(.minutes(1)))
@MainActor
struct BudgetEditorModelStateTests {

    // MARK: Defaults

    @Test("create defaults: title, the default year, an empty draft and the year list")
    func createDefaults() {
        let sut = makeBudgetEditorSUT(mode: .create(years: [2026, 2027, 2028], defaultYear: 2027))

        #expect(sut.model.title == "New Budget")
        #expect(sut.model.draft.year == 2027)
        #expect(sut.model.draft.totalText == "")
        #expect(sut.model.draft.recipients.isEmpty)
        #expect(sut.model.availableYears == [2026, 2027, 2028])
        #expect(sut.model.isYearEditable == true)
        #expect(sut.model.isSaving == false)
        #expect(sut.model.banner == nil)
    }

    @Test("create without a default year starts on the first listed year")
    func createWithoutDefaultYear() {
        let sut = makeBudgetEditorSUT(mode: .create(years: [2027, 2028], defaultYear: nil))

        #expect(sut.model.draft.year == 2027)
    }

    @Test("edit defaults: title, read-only year, total with two decimals and one row per person")
    func editDefaults() {
        let sut = makeEditEditorSUT()

        #expect(sut.model.title == "2026 Budget")
        #expect(sut.model.isYearEditable == false)
        #expect(sut.model.availableYears.isEmpty)
        #expect(sut.model.draft.year == 2026)
        #expect(sut.model.draft.totalText == "500.00")
        #expect(sut.model.draft.recipients.map(\.recipientId) == ["r1", "r2"])
        #expect(sut.model.draft.recipients.map(\.name) == ["Tommy", "Mike"])
        let limits = sut.model.draft.recipients.map { BudgetAmountParser.parse($0.limitText, locale: EditorTest.locale) }
        #expect(limits == [BudgetFixtures.dec("200"), BudgetFixtures.dec("250")])
        #expect(sut.model.banner == nil)
    }

    @Test("edit shows a whole-number total with two decimals and no grouping")
    func editTotalTextHasTwoDecimals() {
        let budget = BudgetFixtures.budget(year: 2026, total: "1000", spent: "0", recipients: [])
        let sut = makeBudgetEditorSUT(mode: .edit(budget))

        #expect(sut.model.draft.totalText == "1000.00")
        #expect(sut.model.draft.recipients.isEmpty)
    }

    @Test("an unchanged edit draft is valid but cannot be saved")
    func editUnchangedIsValid() {
        let sut = makeEditEditorSUT()

        #expect(sut.model.validation.isValid)
        #expect(sut.model.canSave == false)
    }

    // MARK: Editing methods

    @Test("setTotalText and setYear change the draft")
    func setTotalAndYear() {
        let sut = makeBudgetEditorSUT(mode: .create(years: [2026, 2027], defaultYear: 2026))

        sut.model.setTotalText("750.50")
        sut.model.setYear(2027)

        #expect(sut.model.draft.totalText == "750.50")
        #expect(sut.model.draft.year == 2027)
    }

    @Test("addPerson appends a row with an empty limit and the option's name")
    func addPersonAppends() {
        let sut = makeBudgetEditorSUT()

        sut.model.addPerson(EditorTest.alex)

        let rows = sut.model.draft.recipients
        #expect(rows.count == 1)
        #expect(rows.first?.recipientId == "p-a")
        #expect(rows.first?.name == "Alex Giftee")
        #expect(rows.first?.limitText == "")
    }

    @Test("a person cannot be added twice")
    func duplicatePersonImpossible() {
        let sut = makeBudgetEditorSUT()

        sut.model.addPerson(EditorTest.alex)
        sut.model.addPerson(EditorTest.alex)

        #expect(sut.model.draft.recipients.count == 1)
        #expect(!sut.model.validation.issues.contains(.duplicateRecipient(recipientId: "p-a")))
    }

    @Test("setLimitText changes only the named row, and an unknown id changes nothing")
    func setLimitTextTargetsARow() {
        let sut = makeBudgetEditorSUT()
        sut.model.addPerson(EditorTest.alex)
        sut.model.addPerson(EditorTest.casey)

        sut.model.setLimitText("40", for: "p-c")
        let afterKnown = sut.model.draft
        sut.model.setLimitText("99", for: "unknown-id")

        #expect(afterKnown.recipients.map(\.limitText) == ["", "40"])
        #expect(sut.model.draft == afterKnown)
    }

    @Test("removePerson drops the row and keeps the others in order")
    func removePersonDropsRow() {
        let sut = makeBudgetEditorSUT()
        sut.model.addPerson(EditorTest.alex)
        sut.model.addPerson(EditorTest.casey)
        sut.model.addPerson(EditorTest.drew)

        sut.model.removePerson(recipientId: "p-c")

        #expect(sut.model.draft.recipients.map(\.recipientId) == ["p-a", "p-d"])
    }

    // MARK: Validation and summary line

    @Test("under the total: the summary line shows the sum, the total and what is unallocated")
    func summaryUnder() {
        let sut = makeBudgetEditorSUT()
        sut.model.setTotalText("500")
        sut.model.addPerson(EditorTest.alex)
        sut.model.setLimitText("450", for: "p-a")

        #expect(sut.model.validation.isValid)
        #expect(sut.model.summaryLine == "Limits $450.00 of $500.00; $50.00 unallocated")
        #expect(sut.model.summaryIsError == false)
        #expect(sut.model.canSave == true)
    }

    @Test("exactly at the total is valid with nothing unallocated")
    func summaryEqual() {
        let sut = makeBudgetEditorSUT()
        sut.model.setTotalText("500")
        sut.model.addPerson(EditorTest.alex)
        sut.model.setLimitText("500", for: "p-a")

        #expect(sut.model.validation.isValid)
        #expect(sut.model.summaryLine == "Limits $500.00 of $500.00; $0.00 unallocated")
        #expect(sut.model.summaryIsError == false)
        #expect(sut.model.canSave == true)
    }

    @Test("one cent over the total is an error line and disables Save")
    func summaryOver() {
        let sut = makeBudgetEditorSUT()
        sut.model.setTotalText("500")
        sut.model.addPerson(EditorTest.alex)
        sut.model.setLimitText("500.01", for: "p-a")

        #expect(sut.model.validation.issues.contains(.limitsExceedTotal))
        #expect(sut.model.summaryLine == "Limits add up to more than the total")
        #expect(sut.model.summaryIsError == true)
        #expect(sut.model.canSave == false)
    }

    @Test("two limits that together exceed the total are an error")
    func summaryOverWithTwoPeople() {
        let sut = makeBudgetEditorSUT()
        sut.model.setTotalText("100")
        sut.model.addPerson(EditorTest.alex)
        sut.model.addPerson(EditorTest.casey)
        sut.model.setLimitText("60", for: "p-a")
        sut.model.setLimitText("60", for: "p-c")

        #expect(sut.model.summaryIsError == true)
        #expect(sut.model.canSave == false)
    }

    @Test("an invalid total has no summary line, is not an error line and disables Save")
    func invalidTotal() {
        let sut = makeBudgetEditorSUT()
        sut.model.setTotalText("abc")

        #expect(sut.model.validation.issues.contains(.totalInvalid))
        #expect(sut.model.summaryLine == nil)
        #expect(sut.model.summaryIsError == false)
        #expect(sut.model.canSave == false)
    }

    @Test("an empty total, a total over the maximum and a three-decimal total are invalid")
    func invalidTotalBoundaries() {
        let sut = makeBudgetEditorSUT()

        for text in ["", "1000000.00", "10.001", "-5"] {
            sut.model.setTotalText(text)
            #expect(sut.model.validation.issues.contains(.totalInvalid), "total text \"\(text)\"")
            #expect(sut.model.canSave == false, "total text \"\(text)\"")
        }
        sut.model.setTotalText("999999.99")
        #expect(sut.model.validation.isValid)
        #expect(sut.model.canSave == true)
        sut.model.setTotalText("0")
        #expect(sut.model.validation.isValid, "a zero budget is a valid amount")
    }

    @Test("an invalid or empty limit is reported for that person and disables Save")
    func invalidLimit() {
        let sut = makeBudgetEditorSUT()
        sut.model.setTotalText("500")
        sut.model.addPerson(EditorTest.alex)
        #expect(sut.model.validation.issues.contains(.limitInvalid(recipientId: "p-a")), "empty limit")
        #expect(sut.model.canSave == false)

        sut.model.setLimitText("x", for: "p-a")
        #expect(sut.model.validation.issues.contains(.limitInvalid(recipientId: "p-a")))
        #expect(sut.model.canSave == false)

        sut.model.setLimitText("20", for: "p-a")
        #expect(sut.model.validation.isValid)
        #expect(sut.model.canSave == true)
    }

    // MARK: canSave: create

    @Test("create: a valid total with no people can be saved (a total-only budget)")
    func createTotalOnlyCanSave() {
        let sut = makeBudgetEditorSUT()
        sut.model.setTotalText("300")

        #expect(sut.model.draft.recipients.isEmpty)
        #expect(sut.model.canSave == true)
    }

    @Test("create: an empty draft cannot be saved")
    func createEmptyCannotSave() {
        let sut = makeBudgetEditorSUT()

        #expect(sut.model.canSave == false)
    }

    @Test("create: a valid draft cannot be saved when there is no year to choose")
    func createNeedsAYear() {
        let sut = makeBudgetEditorSUT(mode: .create(years: [], defaultYear: nil))
        sut.model.setTotalText("300")

        #expect(sut.model.validation.isValid)
        #expect(sut.model.canSave == false)
    }

    // MARK: canSave: edit (needs a change)

    @Test("edit: changing only the total enables Save, changing it back disables it")
    func editOnlyTotal() {
        let sut = makeEditEditorSUT()

        sut.model.setTotalText("600.00")
        #expect(sut.model.canSave == true)

        sut.model.setTotalText("500.00")
        #expect(sut.model.canSave == false)
    }

    @Test("edit: changing only one limit enables Save")
    func editOnlyLimit() {
        let sut = makeEditEditorSUT()

        sut.model.setLimitText("210.00", for: "r1")

        #expect(sut.model.canSave == true)
    }

    @Test("edit: adding a person enables Save once the new limit is valid")
    func editPersonAdded() {
        let sut = makeEditEditorSUT()

        sut.model.addPerson(EditorTest.alex)
        #expect(sut.model.canSave == false, "the new person's limit is still empty")

        sut.model.setLimitText("10", for: "p-a")
        #expect(sut.model.canSave == true)
    }

    @Test("edit: removing a person enables Save")
    func editPersonRemoved() {
        let sut = makeEditEditorSUT()

        sut.model.removePerson(recipientId: "r2")

        #expect(sut.model.canSave == true)
    }

    @Test("edit: a change that makes the limits exceed the total cannot be saved")
    func editChangeThatIsInvalid() {
        let sut = makeEditEditorSUT()

        sut.model.setTotalText("100.00")

        #expect(sut.model.summaryIsError == true)
        #expect(sut.model.canSave == false)
    }
}
