//
//  RecipientSelectionResolutionTests.swift
//  ChristmasTrackerTests
//
//  Story I3b-M3: the recipient picker keeps its visible selection valid
//  (`CreateListRecipientOptions.resolvedSelection(current:)`) and the create request carries the
//  resolved recipient (`ListFormValidation.makeCreateInput(recipientId:...)`). Fake data only.
//

import Testing
import Foundation
@testable import ChristmasTracker

@Suite("Recipient selection resolution Tests")
struct RecipientSelectionResolutionTests {

    private let currentUserId = "user-me"

    // MARK: - Factory

    private func makeSUT(
        children: [Child] = ChildFixtures.twoChildren(),
        phase: ChildrenLoadPhase = .loaded
    ) -> CreateListRecipientOptions {
        CreateListRecipientOptions(currentUserId: currentUserId, children: children, phase: phase)
    }

    private func makeInput(recipientId: String) -> CreateListInput {
        ListFormValidation.makeCreateInput(
            recipientId: recipientId,
            name: "Christmas 2026",
            theme: "",
            year: 2026,
            visibility: .private
        )
    }

    // MARK: - resolvedSelection

    @Test("A nil selection resolves to the default")
    func nilResolvesToDefault() {
        let state = makeSUT()
        #expect(state.resolvedSelection(current: nil) == state.defaultSelectionId)
        #expect(state.resolvedSelection(current: nil) == currentUserId)
    }

    @Test("An unknown id resolves to the default", arguments: ["child-999", "", "user-other", "CHILD-1"])
    func unknownResolvesToDefault(selection: String) {
        #expect(makeSUT().resolvedSelection(current: selection) == currentUserId)
    }

    @Test("A listed child id is kept", arguments: ["child-1", "child-2"])
    func listedChildKept(selection: String) {
        #expect(makeSUT().resolvedSelection(current: selection) == selection)
    }

    @Test("The self id is kept")
    func selfKept() {
        #expect(makeSUT().resolvedSelection(current: currentUserId) == currentUserId)
    }

    @Test("The self id is kept in every phase",
          arguments: [ChildrenLoadPhase.idle, .loading, .loaded, .failed(.network)])
    func selfKeptInEveryPhase(phase: ChildrenLoadPhase) {
        #expect(makeSUT(phase: phase).resolvedSelection(current: currentUserId) == currentUserId)
    }

    @Test("After idle, loading or a failed load a previously selected child resets to the self id",
          arguments: [ChildrenLoadPhase.idle, .loading, .failed(.network), .failed(.server)])
    func childResetsWhenNotOffered(phase: ChildrenLoadPhase) {
        let state = makeSUT(children: ChildFixtures.twoChildren(), phase: phase)
        #expect(state.resolvedSelection(current: "child-1") == currentUserId)
        #expect(state.resolvedSelection(current: "child-2") == currentUserId)
    }

    @Test("A child that disappears after a reload resets to the self id")
    func vanishedChildResets() {
        let reloaded = makeSUT(children: [ChildFixtures.child(id: "child-2", firstName: "Dana", lastName: "Dependent")])
        #expect(reloaded.resolvedSelection(current: "child-1") == currentUserId)
        #expect(reloaded.resolvedSelection(current: "child-2") == "child-2")
    }

    @Test("With no children loaded only the self id is valid")
    func emptyLoadedOnlySelf() {
        let state = makeSUT(children: [], phase: .loaded)
        #expect(state.resolvedSelection(current: "child-1") == currentUserId)
        #expect(state.resolvedSelection(current: currentUserId) == currentUserId)
    }

    @Test("The resolved selection is always one of the offered options")
    func resolvedIsAnOption() {
        let state = makeSUT()
        for candidate in [nil, "child-1", "child-2", "child-9", currentUserId, ""] as [String?] {
            #expect(state.options.map(\.id).contains(state.resolvedSelection(current: candidate)))
        }
    }

    // MARK: - Request builder with the picker

    @Test("A child recipient is sent as the recipientId")
    func childRecipientInRequest() {
        let state = makeSUT()
        let selection = state.resolvedSelection(current: "child-2")
        let input = makeInput(recipientId: state.recipientId(forSelection: selection))
        #expect(input.recipientId == "child-2")
    }

    @Test("For me sends the current user id")
    func forMeRecipientInRequest() {
        let state = makeSUT()
        let selection = state.resolvedSelection(current: state.defaultSelectionId)
        let input = makeInput(recipientId: state.recipientId(forSelection: selection))
        #expect(input.recipientId == currentUserId)
    }

    @Test("When the selected child vanished the request carries the self id")
    func vanishedSelectionInRequest() {
        let state = makeSUT(children: [], phase: .failed(.network))
        let selection = state.resolvedSelection(current: "child-1")
        #expect(selection == currentUserId)
        #expect(state.recipientId(forSelection: selection) == currentUserId)
        #expect(makeInput(recipientId: state.recipientId(forSelection: selection)).recipientId == currentUserId)
        // Even an unresolved stale selection fed straight to the mapper cannot leak the stale id.
        #expect(makeInput(recipientId: state.recipientId(forSelection: "child-1")).recipientId == currentUserId)
    }

    @Test("The other request fields are unaffected by the recipient")
    func otherFieldsUnchanged() {
        let child = makeInput(recipientId: "child-1")
        let me = makeInput(recipientId: currentUserId)
        #expect(child.name == me.name)
        #expect(child.year == me.year)
        #expect(child.theme == me.theme)
        #expect(child.visibility == me.visibility)
    }
}
