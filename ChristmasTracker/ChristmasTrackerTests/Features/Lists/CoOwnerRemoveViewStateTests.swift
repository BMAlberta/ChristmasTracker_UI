//
//  CoOwnerRemoveViewStateTests.swift
//  ChristmasTrackerTests
//
//  Story I3b-2 R3: the pure view state behind "Remove co-owner" in the edit screen:
//  CoOwnerRemoveConfirmation (dialog texts), CoOwnerRemoval.presentation(for:) and .canRemove,
//  and EditListDetailSource.resolve. All names and ids are fake.
//

import Testing
import Foundation
@testable import ChristmasTracker

@Suite("Co-owner remove view state Tests")
struct CoOwnerRemoveViewStateTests {

    // MARK: - Confirmation texts

    @Test("The confirm button is titled Remove")
    func confirmButtonTitle() {
        #expect(CoOwnerRemoveConfirmation.confirmButtonTitle == "Remove")
    }

    @Test("The title names the co-owner and asks the question")
    func titleText() {
        #expect(CoOwnerRemoveConfirmation.title(displayName: "Cody CoOwner") == "Remove Cody CoOwner as co-owner?")
    }

    @Test("The message says the person will no longer be a co-owner")
    func messageText() {
        #expect(
            CoOwnerRemoveConfirmation.message(displayName: "Cody CoOwner")
                == "Cody CoOwner will no longer be a co-owner of this list."
        )
    }

    @Test("The texts use the display name as given and add no email or id")
    func textsCarryOnlyTheName() {
        let name = "Cody CoOwner"
        for text in [CoOwnerRemoveConfirmation.title(displayName: name), CoOwnerRemoveConfirmation.message(displayName: name)] {
            #expect(text.contains(name))
            #expect(!text.contains("@"))
            #expect(!text.contains("user-"))
        }
    }

    // MARK: - presentation(for:)

    @Test("CancellationError shows nothing")
    func cancellationShowsNothing() {
        #expect(CoOwnerRemoval.presentation(for: CancellationError()) == nil)
    }

    nonisolated static let listErrors: [ListError] = [
        .forbidden, .notFound, .archivedReadOnly, .rateLimited(retryAfter: 12), .network, .server,
        .invalidResponse, .unauthorized, .validation(message: "Not allowed.")
    ]

    @Test("A ListError maps through ListErrorPresentation", arguments: CoOwnerRemoveViewStateTests.listErrors)
    func listErrorMapsThroughPresentation(error: ListError) {
        #expect(CoOwnerRemoval.presentation(for: error) == ListErrorPresentation(error))
    }

    @Test("forbidden is a permission message that stays on the screen")
    func forbidden() throws {
        let presentation = try #require(CoOwnerRemoval.presentation(for: ListError.forbidden))
        #expect(presentation.message == ListError.forbidden.userMessage)
        #expect(!presentation.shouldLeaveScreen)
    }

    @Test("notFound and archivedReadOnly leave the screen")
    func leavingErrors() throws {
        #expect(try #require(CoOwnerRemoval.presentation(for: ListError.notFound)).shouldLeaveScreen)
        #expect(try #require(CoOwnerRemoval.presentation(for: ListError.archivedReadOnly)).shouldLeaveScreen)
    }

    @Test("rateLimited, network, server and invalidResponse are retryable and stay")
    func retryableErrors() throws {
        for error in [ListError.rateLimited(retryAfter: 30), .network, .server, .invalidResponse] {
            let presentation = try #require(CoOwnerRemoval.presentation(for: error))
            #expect(presentation.isRetryable)
            #expect(!presentation.shouldLeaveScreen)
        }
    }

    @Test("An error that is not a ListError is shown as the server error")
    func otherErrorIsServer() {
        struct Unrelated: Error {}
        #expect(CoOwnerRemoval.presentation(for: Unrelated()) == ListErrorPresentation(.server))
        #expect(CoOwnerRemoval.presentation(for: URLError(.notConnectedToInternet)) == ListErrorPresentation(.server))
    }

    @Test("The shown message never contains an email or an id")
    func messagesAreClean() throws {
        for error in Self.listErrors {
            let message = try #require(CoOwnerRemoval.presentation(for: error)).message
            #expect(!message.contains("@"))
            #expect(!message.contains("list-"))
        }
    }

    // MARK: - canRemove

    @Test("canRemove is true only when neither a mutation nor a save is in flight",
          arguments: [(false, false, true), (true, false, false), (false, true, false), (true, true, false)])
    func canRemoveTruthTable(isMutating: Bool, isSaving: Bool, expected: Bool) {
        #expect(CoOwnerRemoval.canRemove(isMutating: isMutating, isSaving: isSaving) == expected)
    }

    // MARK: - EditRetry (Try Again re-runs the action that failed)

    @Test("Try Again after a failed removal re-runs the removal")
    func retryAfterRemovalIsRemoval() {
        #expect(EditRetry.action(after: .removeCoOwner) == .removeCoOwner)
    }

    @Test("Try Again after a failed save re-runs the save")
    func retryAfterSaveIsSave() {
        #expect(EditRetry.action(after: .save) == .save)
    }

    @Test("With no failed action there is nothing to retry")
    func retryWithNothingFailedIsNil() {
        #expect(EditRetry.action(after: nil) == nil)
    }

    @Test("A failed removal never retries as a save and a failed save never as a removal")
    func retryNeverCrossesActions() {
        #expect(EditRetry.action(after: .removeCoOwner) != .save)
        #expect(EditRetry.action(after: .save) != .removeCoOwner)
    }

    // MARK: - EditListDetailSource.resolve

    private func makeDetail(id: String, name: String) throws -> ListDetail {
        var spec = ListFixtures.Spec()
        spec.id = id
        spec.name = name
        spec.flags.canSetCoOwner = true
        spec.coOwner = (id: MembersFixtures.coOwnerId, name: MembersFixtures.coOwnerName)
        return mapListDetail(try ListFixtures.detail(spec))
    }

    @Test("The live detail wins when it has the same id as the snapshot")
    func sameIdUsesLive() throws {
        let snapshot = try makeDetail(id: "list-a", name: "Snapshot Name")
        let live = try makeDetail(id: "list-a", name: "Live Name")
        #expect(EditListDetailSource.resolve(snapshot: snapshot, live: live) == live)
    }

    @Test("A live detail of another list is ignored")
    func differentIdUsesSnapshot() throws {
        let snapshot = try makeDetail(id: "list-a", name: "Snapshot Name")
        let other = try makeDetail(id: "list-b", name: "Other Name")
        #expect(EditListDetailSource.resolve(snapshot: snapshot, live: other) == snapshot)
    }

    @Test("No live detail falls back to the snapshot")
    func nilLiveUsesSnapshot() throws {
        let snapshot = try makeDetail(id: "list-a", name: "Snapshot Name")
        #expect(EditListDetailSource.resolve(snapshot: snapshot, live: nil) == snapshot)
    }

    @Test("After removal the resolved detail has no co-owner, so the Remove control disappears")
    func resolvedDetailAfterRemovalHidesRemove() throws {
        let snapshot = try makeDetail(id: "list-a", name: "Same Name")
        var spec = ListFixtures.Spec()
        spec.id = "list-a"
        spec.name = "Same Name"
        spec.flags.canSetCoOwner = true
        spec.coOwner = nil
        let returned = mapListDetail(try ListFixtures.detail(spec))

        #expect(CoOwnerSectionState(detail: snapshot).showsRemove)
        let resolved = EditListDetailSource.resolve(snapshot: snapshot, live: returned)
        let state = CoOwnerSectionState(detail: resolved)
        #expect(!state.showsRemove)
        #expect(state.showsChange)
        #expect(state.currentCoOwnerName == nil)
    }
}
