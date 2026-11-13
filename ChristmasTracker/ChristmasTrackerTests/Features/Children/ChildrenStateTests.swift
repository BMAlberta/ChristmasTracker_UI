//
//  ChildrenStateTests.swift
//  ChristmasTrackerTests
//
//  Story I3b-M1: ChildrenState rows, phases and the delete confirmation. Fake names only.
//

import Testing
import Foundation
@testable import ChristmasTracker

@Suite("ChildrenState Tests")
struct ChildrenStateTests {

    // MARK: - Factory

    private func makeSUT(
        children: [Child] = ChildFixtures.twoChildren(),
        phase: ChildrenLoadPhase = .loaded
    ) -> ChildrenState {
        ChildrenState(children: children, phase: phase)
    }

    // MARK: - Rows

    @Test("One row per child, in order, with the shown name as title")
    func rows() {
        let state = makeSUT()
        #expect(state.rows.map(\.id) == ["child-1", "child-2"])
        #expect(state.rows.map(\.title) == ["Charlie C", "Dana Dependent"])
    }

    @Test("Row titles use the display name when present and first plus last name otherwise")
    func rowTitleUsesShownName() {
        let children = ChildFixtures.twoChildren()
        let state = makeSUT(children: children)
        #expect(state.rows.map(\.title) == children.map(\.shownName))
    }

    @Test("Row relationship titles come from the relationship")
    func rowRelationshipTitles() {
        let state = makeSUT()
        #expect(state.rows.map(\.relationshipTitle) == ["Parent", "Guardian"])
    }

    @Test("The accessibility label has the name and the relationship but not the id")
    func accessibilityLabel() {
        let state = makeSUT()
        for row in state.rows {
            #expect(row.accessibilityLabel.contains(row.title))
            #expect(row.accessibilityLabel.contains(row.relationshipTitle))
            #expect(!row.accessibilityLabel.contains(row.id))
        }
    }

    @Test("A child with a blank display name shows first and last name")
    func blankDisplayNameRow() {
        let child = ChildFixtures.child(id: "child-3", firstName: "Eli", lastName: "Example", displayName: "  ")
        #expect(makeSUT(children: [child]).rows.first?.title == "Eli Example")
    }

    // MARK: - Phases

    @Test("Loading shows the loading state and nothing else")
    func loadingPhase() {
        let state = makeSUT(children: [], phase: .loading)
        #expect(state.showsLoading)
        #expect(!state.showsEmptyState)
        #expect(state.errorMessage == nil)
    }

    @Test("Loaded with no children shows the empty state")
    func emptyPhase() {
        let state = makeSUT(children: [], phase: .loaded)
        #expect(state.showsEmptyState)
        #expect(!state.showsLoading)
        #expect(state.rows.isEmpty)
        #expect(state.errorMessage == nil)
    }

    @Test("The empty text is plain")
    func emptyText() {
        #expect(makeSUT(children: [], phase: .loaded).emptyText == "No children added yet.")
    }

    @Test("Loaded with children shows rows and no empty state")
    func loadedPhase() {
        let state = makeSUT()
        #expect(!state.showsEmptyState)
        #expect(!state.showsLoading)
        #expect(state.rows.count == 2)
        #expect(state.errorMessage == nil)
    }

    @Test("Idle with no children shows neither loading nor the empty state")
    func idlePhase() {
        let state = makeSUT(children: [], phase: .idle)
        #expect(!state.showsLoading)
        #expect(!state.showsEmptyState)
        #expect(state.errorMessage == nil)
    }

    @Test("A failed load shows the presented message and no empty state",
          arguments: [ChildError.network, .server, .unauthorized, .rateLimited(retryAfter: 20), .invalidResponse])
    func failedPhase(error: ChildError) {
        let state = makeSUT(children: [], phase: .failed(error))
        #expect(state.errorMessage == ChildErrorPresentation(error).message)
        #expect(!state.showsEmptyState)
        #expect(!state.showsLoading)
    }

    @Test("Phases are Equatable on their error")
    func phaseEquatable() {
        #expect(ChildrenLoadPhase.failed(.network) == .failed(.network))
        #expect(ChildrenLoadPhase.failed(.network) != .failed(.server))
        #expect(ChildrenLoadPhase.loading != .loaded)
        #expect(ChildrenLoadPhase.idle != .loading)
    }

    // MARK: - Delete confirmation

    // Changed in I3d-D3 (the three tests below): this story replaces
    // ChildrenState.deleteConfirmation(for:) by deleteConfirmation(for:plan:), so each test is
    // rewritten for the new signature. The old assertion that the message contains "undone" is
    // dropped for deleteNow (its message is now "<name> will be removed.") and kept for
    // archiveThenDelete. The full text tables live in ChildrenDeleteStateTests.

    @Test("The archive-then-delete confirmation names the child and warns it cannot be undone")
    func deleteConfirmation() throws {
        let child = ChildFixtures.child(firstName: "Charlie", lastName: "Child", displayName: "Charlie C")
        let confirmation = try #require(
            ChildrenState.deleteConfirmation(for: child, plan: .archiveThenDelete(listIds: ["list-1"]))
        )
        #expect(!confirmation.title.isEmpty)
        #expect(confirmation.message.contains(child.shownName))
        #expect(confirmation.message.lowercased().contains("undone"))
        #expect(!confirmation.confirmButtonTitle.isEmpty)
    }

    @Test("The delete-now confirmation names the child and has a title and a button")
    func deleteConfirmationDeleteNow() throws {
        let child = ChildFixtures.child(firstName: "Charlie", lastName: "Child", displayName: "Charlie C")
        let confirmation = try #require(ChildrenState.deleteConfirmation(for: child, plan: .deleteNow))
        #expect(!confirmation.title.isEmpty)
        #expect(confirmation.message.contains(child.shownName))
        #expect(!confirmation.confirmButtonTitle.isEmpty)
    }

    @Test("The delete confirmation follows the shown name when there is no display name",
          arguments: [ChildDeletionPlan.deleteNow, .archiveThenDelete(listIds: ["list-1", "list-2"])])
    func deleteConfirmationFallbackName(plan: ChildDeletionPlan) throws {
        let child = ChildFixtures.child(firstName: "Dana", lastName: "Dependent", displayName: nil)
        let confirmation = try #require(ChildrenState.deleteConfirmation(for: child, plan: plan))
        #expect(confirmation.message.contains("Dana Dependent"))
    }

    @Test("The delete confirmation never contains the child id or a list id",
          arguments: [ChildDeletionPlan.deleteNow, .archiveThenDelete(listIds: ["list-secret-1", "list-secret-2"])])
    func deleteConfirmationHasNoId(plan: ChildDeletionPlan) throws {
        let child = ChildFixtures.child(id: "child-secret-7")
        let confirmation = try #require(ChildrenState.deleteConfirmation(for: child, plan: plan))
        for text in [confirmation.title, confirmation.message, confirmation.confirmButtonTitle] {
            #expect(!text.contains("child-secret-7"))
            #expect(!text.contains("list-secret"))
        }
    }
}
