//
//  CreateListRecipientOptionsTests.swift
//  ChristmasTrackerTests
//
//  Story I3b-M1: the recipient picker of the create-list form. "For me" is always present, so a
//  failed or slow child fetch never blocks creating a list for yourself (soft fail).
//

import Testing
import Foundation
@testable import ChristmasTracker

@Suite("CreateListRecipientOptions Tests")
struct CreateListRecipientOptionsTests {

    private let currentUserId = "user-me"

    // MARK: - Factory

    private func makeSUT(
        children: [Child] = ChildFixtures.twoChildren(),
        phase: ChildrenLoadPhase = .loaded
    ) -> CreateListRecipientOptions {
        CreateListRecipientOptions(currentUserId: currentUserId, children: children, phase: phase)
    }

    // MARK: - Options

    @Test("For me comes first with the current user's id")
    func forMeFirst() throws {
        let first = try #require(makeSUT().options.first)
        #expect(first.title == "For me")
        #expect(first.id == currentUserId)
        #expect(first.isSelf)
    }

    @Test("Each child follows in order, titled by the shown name, not self")
    func childOptions() {
        let options = makeSUT().options
        #expect(options.map(\.id) == [currentUserId, "child-1", "child-2"])
        #expect(options.map(\.title) == ["For me", "Charlie C", "Dana Dependent"])
        #expect(options.map(\.isSelf) == [true, false, false])
    }

    @Test("The default selection is the current user")
    func defaultSelection() {
        #expect(makeSUT().defaultSelectionId == currentUserId)
        #expect(makeSUT(children: [], phase: .loading).defaultSelectionId == currentUserId)
    }

    @Test("The default selection is one of the options")
    func defaultSelectionIsAnOption() {
        let state = makeSUT()
        #expect(state.options.map(\.id).contains(state.defaultSelectionId))
    }

    // MARK: - Soft failure

    @Test("Loading still offers For me and no children, even if children were passed in")
    func loadingKeepsForMe() {
        let state = makeSUT(children: ChildFixtures.twoChildren(), phase: .loading)
        #expect(state.options.map(\.id) == [currentUserId])
        #expect(state.showsLoading)
        #expect(state.errorMessage == nil)
    }

    @Test("A failed fetch still offers For me, shows the message and no children",
          arguments: [ChildError.network, .server, .unauthorized, .rateLimited(retryAfter: 10)])
    func failedKeepsForMe(error: ChildError) {
        let state = makeSUT(children: ChildFixtures.twoChildren(), phase: .failed(error))
        #expect(state.options.map(\.id) == [currentUserId])
        #expect(state.options.first?.isSelf == true)
        #expect(state.errorMessage == ChildErrorPresentation(error).message)
        #expect(!state.showsLoading)
        #expect(!state.showsEmptyHint)
    }

    @Test("Idle offers For me only")
    func idleOffersForMe() {
        let state = makeSUT(children: [], phase: .idle)
        #expect(state.options.map(\.id) == [currentUserId])
        #expect(!state.showsLoading)
        #expect(!state.showsEmptyHint)
        #expect(state.errorMessage == nil)
    }

    // MARK: - Empty and loaded

    @Test("Loaded with no children shows the empty hint and only For me")
    func emptyHint() {
        let state = makeSUT(children: [], phase: .loaded)
        #expect(state.showsEmptyHint)
        #expect(state.options.map(\.id) == [currentUserId])
        #expect(!state.showsLoading)
        #expect(state.errorMessage == nil)
    }

    @Test("Loaded with children shows no hint, no loading and no error")
    func loadedWithChildren() {
        let state = makeSUT()
        #expect(!state.showsEmptyHint)
        #expect(!state.showsLoading)
        #expect(state.errorMessage == nil)
    }

    // MARK: - Resolving the selection

    @Test("A selected child resolves to the child's id")
    func resolvesChild() {
        #expect(makeSUT().recipientId(forSelection: "child-2") == "child-2")
        #expect(makeSUT().recipientId(forSelection: "child-1") == "child-1")
    }

    @Test("The self selection resolves to the current user")
    func resolvesSelf() {
        #expect(makeSUT().recipientId(forSelection: currentUserId) == currentUserId)
    }

    @Test("A nil selection resolves to the current user")
    func resolvesNil() {
        #expect(makeSUT().recipientId(forSelection: nil) == currentUserId)
    }

    @Test("An unknown selection resolves to the current user, never to an arbitrary id",
          arguments: ["child-999", "", "user-other"])
    func resolvesUnknown(selection: String) {
        #expect(makeSUT().recipientId(forSelection: selection) == currentUserId)
    }

    @Test("A child that is no longer offered (failed reload) resolves to the current user")
    func resolvesChildNoLongerOffered() {
        let state = makeSUT(children: ChildFixtures.twoChildren(), phase: .failed(.network))
        #expect(state.recipientId(forSelection: "child-1") == currentUserId)
    }

    // MARK: - Option value type

    @Test("RecipientOption is Identifiable and Equatable")
    func optionValue() {
        let option = RecipientOption(id: "child-1", title: "Charlie C", isSelf: false)
        #expect(option.id == "child-1")
        #expect(option == RecipientOption(id: "child-1", title: "Charlie C", isSelf: false))
        #expect(option != RecipientOption(id: "child-1", title: "Charlie C", isSelf: true))
    }
}
