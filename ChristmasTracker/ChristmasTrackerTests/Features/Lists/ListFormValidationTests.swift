//
//  ListFormValidationTests.swift
//  ChristmasTrackerTests
//
//  Story I3a-L3: create and edit form rules and the request builders. Fake data only.
//
//  Assumed names (the addendum leaves them open): CreateFormValidity and EditFormValidity
//  expose Bool members nameEmptyOrTooLong, themeTooLong, yearOutOfRange (create only) and
//  isValid. `ListVisibility.title` is the per-value title.
//
//  Decision on clearing a theme: UpdateListInput.theme is String?, where nil means "leave
//  unchanged", so the only way to clear is to send the empty string. When the original had a
//  theme and the field is blank, makeUpdateInput sends "". When the original had none and the
//  field is blank, nothing changed.
//

import Testing
import Foundation
@testable import ChristmasTracker

@Suite("List form validation Tests")
struct ListFormValidationTests {

    // MARK: - Helpers

    private func text(_ count: Int) -> String {
        String(repeating: "a", count: count)
    }

    private func original(theme: String? = nil, visibility: ListVisibility = .private) -> ListDetail {
        let base = ListFixtures.listDetail(name: "Fake Family List")
        let changed = base.applying(UpdateListInput(name: nil, theme: theme, visibility: visibility), at: base.updatedAt)
        return changed
    }

    // MARK: - validateCreate: name

    @Test("Create name boundaries", arguments: [
        (0, false), (1, true), (200, true), (201, false)
    ])
    func createNameBoundaries(length: Int, valid: Bool) {
        let result = ListFormValidation.validateCreate(name: text(length), theme: "", year: 2026)
        #expect(result.nameEmptyOrTooLong == !valid)
        #expect(result.isValid == valid)
    }

    @Test("Whitespace-only name is invalid")
    func createWhitespaceName() {
        let result = ListFormValidation.validateCreate(name: "   \n\t ", theme: "", year: 2026)
        #expect(result.nameEmptyOrTooLong)
        #expect(!result.isValid)
    }

    @Test("Name length is measured after trimming")
    func createNameTrimmedLength() {
        let padded = "  " + text(200) + "  "
        #expect(ListFormValidation.validateCreate(name: padded, theme: "", year: 2026).isValid)
        let tooLong = "  " + text(201) + "  "
        #expect(ListFormValidation.validateCreate(name: tooLong, theme: "", year: 2026).nameEmptyOrTooLong)
    }

    // MARK: - validateCreate: theme

    @Test("Create theme boundaries", arguments: [
        (0, false), (500, false), (501, true)
    ])
    func createThemeBoundaries(length: Int, tooLong: Bool) {
        let result = ListFormValidation.validateCreate(name: "Fake List", theme: text(length), year: 2026)
        #expect(result.themeTooLong == tooLong)
        #expect(result.isValid == !tooLong)
    }

    @Test("A whitespace-only theme is valid (it is sent as nothing)")
    func createBlankThemeValid() {
        #expect(ListFormValidation.validateCreate(name: "Fake List", theme: "    ", year: 2026).isValid)
    }

    // MARK: - validateCreate: year

    @Test("Create year boundaries", arguments: [
        (1999, true), (2000, false), (2100, false), (2101, true)
    ])
    func createYearBoundaries(year: Int, outOfRange: Bool) {
        let result = ListFormValidation.validateCreate(name: "Fake List", theme: "", year: year)
        #expect(result.yearOutOfRange == outOfRange)
        #expect(result.isValid == !outOfRange)
    }

    @Test("Several problems are reported together")
    func createReportsEveryProblem() {
        let result = ListFormValidation.validateCreate(name: "", theme: text(501), year: 1990)
        #expect(result.nameEmptyOrTooLong)
        #expect(result.themeTooLong)
        #expect(result.yearOutOfRange)
        #expect(!result.isValid)
    }

    @Test("A fully valid create form has no problems")
    func createAllGood() {
        let result = ListFormValidation.validateCreate(name: "Fake List", theme: "Cosy", year: 2026)
        #expect(!result.nameEmptyOrTooLong)
        #expect(!result.themeTooLong)
        #expect(!result.yearOutOfRange)
        #expect(result.isValid)
    }

    // MARK: - validateEdit

    @Test("Edit name boundaries", arguments: [
        (0, false), (1, true), (200, true), (201, false)
    ])
    func editNameBoundaries(length: Int, valid: Bool) {
        let result = ListFormValidation.validateEdit(name: text(length), theme: "")
        #expect(result.nameEmptyOrTooLong == !valid)
        #expect(result.isValid == valid)
    }

    @Test("Edit whitespace-only name is invalid")
    func editWhitespaceName() {
        #expect(ListFormValidation.validateEdit(name: "  ", theme: "").nameEmptyOrTooLong)
    }

    @Test("Edit theme boundaries", arguments: [
        (0, false), (500, false), (501, true)
    ])
    func editThemeBoundaries(length: Int, tooLong: Bool) {
        let result = ListFormValidation.validateEdit(name: "Fake List", theme: text(length))
        #expect(result.themeTooLong == tooLong)
        #expect(result.isValid == !tooLong)
    }

    // MARK: - makeCreateInput

    @Test("Create input trims the name and theme and passes the recipient, year and visibility through")
    func createInputTrims() {
        let input = ListFormValidation.makeCreateInput(
            recipientId: "user-1", name: "  Fake List  ", theme: "  Cosy  ", year: 2027, visibility: .inviteOnly
        )
        #expect(input == CreateListInput(
            recipientId: "user-1", year: 2027, name: "Fake List", theme: "Cosy", visibility: .inviteOnly
        ))
    }

    @Test("A blank theme becomes nil")
    func createInputBlankTheme() {
        let empty = ListFormValidation.makeCreateInput(recipientId: "user-1", name: "Fake", theme: "", year: 2026, visibility: .private)
        #expect(empty.theme == nil)
        let spaces = ListFormValidation.makeCreateInput(recipientId: "user-1", name: "Fake", theme: " \n ", year: 2026, visibility: .private)
        #expect(spaces.theme == nil)
    }

    @Test("Every visibility is passed through to the create input", arguments: [
        ListVisibility.private, .inviteOnly, .friendsOnly, .public
    ])
    func createInputVisibility(visibility: ListVisibility) {
        let input = ListFormValidation.makeCreateInput(recipientId: "user-1", name: "Fake", theme: "", year: 2026, visibility: visibility)
        #expect(input.visibility == visibility)
    }

    // MARK: - makeUpdateInput

    @Test("Nothing changed gives nil")
    func updateNothingChanged() {
        let list = original(theme: "Cosy", visibility: .inviteOnly)
        #expect(ListFormValidation.makeUpdateInput(original: list, name: list.name, theme: "Cosy", visibility: .inviteOnly) == nil)
    }

    @Test("Differences in surrounding whitespace only are not changes")
    func updateWhitespaceOnlyIsNoChange() {
        let list = original(theme: "Cosy")
        #expect(ListFormValidation.makeUpdateInput(original: list, name: "  \(list.name)  ", theme: " Cosy ", visibility: .private) == nil)
    }

    @Test("A nil original theme and a blank field is no change")
    func updateBlankThemeFromNil() {
        let list = original(theme: nil)
        #expect(ListFormValidation.makeUpdateInput(original: list, name: list.name, theme: "  ", visibility: .private) == nil)
    }

    @Test("Only the name changed")
    func updateNameOnly() {
        let list = original(theme: "Cosy")
        let input = ListFormValidation.makeUpdateInput(original: list, name: "  Fake Renamed  ", theme: "Cosy", visibility: .private)
        #expect(input == UpdateListInput(name: "Fake Renamed", theme: nil, visibility: nil))
    }

    @Test("Only the theme changed")
    func updateThemeOnly() {
        let list = original(theme: "Cosy")
        let input = ListFormValidation.makeUpdateInput(original: list, name: list.name, theme: " Snowy ", visibility: .private)
        #expect(input == UpdateListInput(name: nil, theme: "Snowy", visibility: nil))
    }

    @Test("A theme set where none existed")
    func updateThemeFromNil() {
        let list = original(theme: nil)
        let input = ListFormValidation.makeUpdateInput(original: list, name: list.name, theme: "Snowy", visibility: .private)
        #expect(input == UpdateListInput(name: nil, theme: "Snowy", visibility: nil))
    }

    @Test("Only the visibility changed")
    func updateVisibilityOnly() {
        let list = original(theme: "Cosy", visibility: .private)
        let input = ListFormValidation.makeUpdateInput(original: list, name: list.name, theme: "Cosy", visibility: .friendsOnly)
        #expect(input == UpdateListInput(name: nil, theme: nil, visibility: .friendsOnly))
    }

    @Test("Clearing an existing theme sends the empty string (nil would mean unchanged)")
    func updateClearTheme() {
        let list = original(theme: "Cosy")
        let input = ListFormValidation.makeUpdateInput(original: list, name: list.name, theme: "   ", visibility: .private)
        #expect(input == UpdateListInput(name: nil, theme: "", visibility: nil))
    }

    @Test("Several fields changed")
    func updateEverything() {
        let list = original(theme: "Cosy", visibility: .private)
        let input = ListFormValidation.makeUpdateInput(original: list, name: "Fake Other", theme: "Snowy", visibility: .public)
        #expect(input == UpdateListInput(name: "Fake Other", theme: "Snowy", visibility: .public))
    }

    // MARK: - selectableVisibilities

    @Test("Four selectable visibilities in order, including friendsOnly")
    func selectableVisibilities() {
        #expect(ListFormValidation.selectableVisibilities == [.private, .inviteOnly, .friendsOnly, .public])
    }

    @Test("Visibility titles are non-empty, distinct and recognisable")
    func visibilityTitles() {
        let titles = ListFormValidation.selectableVisibilities.map(\.title)
        #expect(titles.allSatisfy { !$0.isEmpty })
        #expect(Set(titles).count == 4)
        #expect(ListVisibility.private.title.lowercased().contains("private"))
        #expect(ListVisibility.inviteOnly.title.lowercased().contains("invite"))
        #expect(ListVisibility.friendsOnly.title.lowercased().contains("friends"))
        #expect(ListVisibility.public.title.lowercased().contains("public"))
    }
}
