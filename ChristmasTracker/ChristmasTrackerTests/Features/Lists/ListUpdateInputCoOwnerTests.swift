//
//  ListUpdateInputCoOwnerTests.swift
//  ChristmasTrackerTests
//
//  Story I3b-M1: ListFormValidation.makeUpdateInput with the co-owner change. A change of the
//  co-owner alone is a change (non-nil result); nothing changed at all is still nil.
//

import Testing
import Foundation
@testable import ChristmasTracker

@Suite("List update input co-owner Tests")
struct ListUpdateInputCoOwnerTests {

    // MARK: - Factory

    private func makeOriginal() -> ListDetail {
        ListFixtures.listDetail(name: "Fake Family List")
    }

    private func makeInput(
        name: String? = nil,
        theme: String = "",
        visibility: ListVisibility = .private,
        coOwner: CoOwnerChange
    ) -> UpdateListInput? {
        let original = makeOriginal()
        return ListFormValidation.makeUpdateInput(
            original: original, name: name ?? original.name, theme: theme, visibility: visibility, coOwner: coOwner
        )
    }

    // MARK: - Only the co-owner changed

    @Test("Setting a co-owner alone gives an input that carries only the co-owner")
    func setOnly() {
        let input = makeInput(coOwner: .set(email: "cody@example.com"))
        #expect(input == UpdateListInput(
            name: nil, theme: nil, visibility: nil, coOwner: .set(email: "cody@example.com")
        ))
    }

    // MARK: - Nothing changed

    @Test("Nothing changed with an explicit unchanged co-owner is nil")
    func nothingChangedExplicit() {
        #expect(makeInput(coOwner: .unchanged) == nil)
    }

    @Test("Nothing changed with the co-owner argument left out is nil (existing calls keep working)")
    func nothingChangedDefault() {
        let original = makeOriginal()
        let input = ListFormValidation.makeUpdateInput(
            original: original, name: original.name, theme: "", visibility: .private
        )
        #expect(input == nil)
    }

    // MARK: - Together with other fields

    @Test("A name change with a co-owner change carries both")
    func nameAndCoOwner() {
        let input = makeInput(name: "  Fake Renamed ", coOwner: .set(email: "cody@example.com"))
        #expect(input == UpdateListInput(
            name: "Fake Renamed", theme: nil, visibility: nil, coOwner: .set(email: "cody@example.com")
        ))
    }

    @Test("A visibility change with an unchanged co-owner leaves the co-owner unchanged")
    func visibilityKeepsCoOwnerUnchanged() {
        let input = makeInput(visibility: .public, coOwner: .unchanged)
        #expect(input == UpdateListInput(name: nil, theme: nil, visibility: .public))
        #expect(input?.coOwner == .unchanged)
    }

    @Test("Existing calls without a co-owner still produce an unchanged co-owner")
    func existingCallsDefault() {
        let original = makeOriginal()
        let input = ListFormValidation.makeUpdateInput(
            original: original, name: "Fake Other", theme: "", visibility: .private
        )
        #expect(input == UpdateListInput(name: "Fake Other", theme: nil, visibility: nil))
        #expect(input?.coOwner == .unchanged)
    }

    @Test("The co-owner email is passed through exactly as the caller built it")
    func emailPassedThrough() {
        let input = makeInput(coOwner: .set(email: "cody@example.com"))
        #expect(input?.coOwner == .set(email: "cody@example.com"))
    }
}
