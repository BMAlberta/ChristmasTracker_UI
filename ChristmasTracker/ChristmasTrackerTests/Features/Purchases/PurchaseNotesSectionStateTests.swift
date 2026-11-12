//
//  PurchaseNotesSectionStateTests.swift
//  ChristmasTrackerTests
//
//  Story I4b-A: the notes section of the purchase detail. canSave is `update != nil && !tooLong`;
//  tooLong when the TRIMMED draft has more than 1000 UTF-16 units; remainingCharacters is 1000
//  minus the (untrimmed) draft UTF-16 count and may be negative; applying(_:) resets from a
//  returned purchase.
//
//  The construction and the `editing` copy are the assumed shape (see the story report):
//  `PurchaseNotesSectionState(purchase:)` and `editing(text:)`.
//
//  Fails today because PurchaseNotesSectionState does not exist yet.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("Purchase notes section state Tests")
struct PurchaseNotesSectionStateTests {

    private func makeSUT(notes: String? = "Gift wrap") -> PurchaseNotesSectionState {
        PurchaseNotesSectionState(purchase: PurchaseFixtures.recordedPurchase(notes: notes))
    }

    private func units(_ count: Int) -> String { String(repeating: "a", count: count) }

    @Test("A fresh section mirrors the notes and has nothing to save")
    func fresh() {
        let sut = makeSUT(notes: "Gift wrap")
        #expect(sut.draftText == "Gift wrap")
        #expect(sut.update == nil)
        #expect(!sut.canSave)
        #expect(!sut.tooLong)
    }

    @Test("A purchase without notes starts with an empty draft")
    func freshWithoutNotes() {
        let sut = makeSUT(notes: nil)
        #expect(sut.draftText == "")
        #expect(sut.update == nil)
        #expect(!sut.canSave)
    }

    @Test("Editing the text enables Save with a set of the trimmed text")
    func edit() {
        let sut = makeSUT().editing(text: "  Different note \n")
        #expect(sut.update?.change == .set("Different note"))
        #expect(sut.canSave)
    }

    @Test("Whitespace-only differences are not a change", arguments: ["Gift wrap", "  Gift wrap", "Gift wrap\n\n"])
    func whitespaceOnlyDifference(text: String) {
        let sut = makeSUT().editing(text: text)
        #expect(sut.update == nil)
        #expect(!sut.canSave)
    }

    @Test("Typing only whitespace into an empty notes field is not a change", arguments: ["", "  ", "\n\t"])
    func whitespaceIntoEmpty(text: String) {
        let sut = makeSUT(notes: nil).editing(text: text)
        #expect(sut.update == nil)
        #expect(!sut.canSave)
    }

    @Test("Clearing the field of a non-empty note is a clear and can be saved", arguments: ["", "   ", "\n"])
    func clear(text: String) {
        let sut = makeSUT().editing(text: text)
        #expect(sut.update?.change == .clear)
        #expect(sut.update?.wireNotes == "")
        #expect(sut.canSave)
    }

    @Test("Typing back the original text disables Save again")
    func revert() {
        let sut = makeSUT().editing(text: "Other").editing(text: "Gift wrap")
        #expect(sut.update == nil)
        #expect(!sut.canSave)
    }

    // MARK: - Limit (1000 UTF-16 units, trimmed)

    @Test("Exactly 1000 units is allowed, 1001 is too long and blocks Save", arguments: [
        (1000, false), (1001, true), (999, false), (2000, true)
    ])
    func limit(count: Int, tooLong: Bool) {
        let sut = makeSUT(notes: nil).editing(text: units(count))
        #expect(sut.tooLong == tooLong)
        #expect(sut.canSave == !tooLong)
        #expect(sut.update != nil)
    }

    @Test("The limit applies to the trimmed text while remaining characters counts the whole draft")
    func limitTrimmedRemainingUntrimmed() {
        let sut = makeSUT(notes: nil).editing(text: units(1000) + "   ")
        #expect(!sut.tooLong)
        #expect(sut.canSave)
        #expect(sut.remainingCharacters == -3)
    }

    @Test("An emoji counts as two UTF-16 units at the boundary")
    func emojiBoundary() {
        let atLimit = makeSUT(notes: nil).editing(text: units(998) + "\u{1F600}")
        #expect(!atLimit.tooLong)
        #expect(atLimit.canSave)
        #expect(atLimit.remainingCharacters == 0)
        let overLimit = makeSUT(notes: nil).editing(text: units(999) + "\u{1F600}")
        #expect(overLimit.tooLong)
        #expect(!overLimit.canSave)
        #expect(overLimit.remainingCharacters == -1)
    }

    @Test("Remaining characters is 1000 minus the draft length and may be negative", arguments: [
        (0, 1000), (1, 999), (1000, 0), (1005, -5)
    ])
    func remaining(count: Int, expected: Int) {
        #expect(makeSUT(notes: nil).editing(text: units(count)).remainingCharacters == expected)
    }

    // MARK: - applying

    @Test("Applying a returned purchase resets original and draft, leaving nothing to save")
    func applyingResets() {
        let edited = makeSUT().editing(text: "New note")
        #expect(edited.canSave)
        let applied = edited.applying(PurchaseFixtures.recordedPurchase(notes: "New note"))
        #expect(applied.draftText == "New note")
        #expect(applied.update == nil)
        #expect(!applied.canSave)
    }

    @Test("Applying a purchase whose notes were cleared resets the draft to empty")
    func applyingCleared() {
        let applied = makeSUT().editing(text: "").applying(PurchaseFixtures.recordedPurchase(notes: nil))
        #expect(applied.draftText == "")
        #expect(applied.update == nil)
        #expect(applied.remainingCharacters == 1000)
    }

    @Test("After applying, the returned purchase is the new baseline for the next change")
    func applyingNewBaseline() {
        let applied = makeSUT().applying(PurchaseFixtures.recordedPurchase(notes: "Returned"))
        #expect(applied.editing(text: "Gift wrap").update?.change == .set("Gift wrap"))
        #expect(applied.editing(text: "").update?.change == .clear)
    }
}
