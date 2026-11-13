//
//  ChildrenDeleteStateTests.swift
//  ChristmasTrackerTests
//
//  Story I3d-D3: the pure presentation of the child deletion flow (confirmation per plan, blocked
//  message, banner per result, VoiceOver announcements, row progress, control gating).
//  Fake names and ids only.
//

import Testing
import Foundation
@testable import ChristmasTracker

@Suite("Children delete presentation Tests")
struct ChildrenDeleteStateTests {

    private nonisolated static let allErrors: [ChildError] = [
        .childNotFound, .childHasLists, .validation(message: "Name is bad"), .rateLimited(retryAfter: 20),
        .unauthorized, .sessionEnded, .network, .invalidResponse, .server, .forbidden
    ]

    // MARK: - Factory

    private func makeChild(id: String = "child-secret-7") -> Child {
        ChildFixtures.child(id: id, firstName: "Test", lastName: "Kid", displayName: "Test Kid")
    }

    private func makeSUT(
        children: [Child] = ChildFixtures.twoChildren(),
        deletion: ChildDeletionPresentation = .idle
    ) -> ChildrenState {
        ChildrenState(children: children, phase: .loaded, deletion: deletion)
    }

    // MARK: - Confirmation per plan

    @Test("deleteNow: plain title, message with the name, Delete button")
    func deleteNowConfirmation() throws {
        let confirmation = try #require(ChildrenState.deleteConfirmation(for: makeChild(), plan: .deleteNow))
        #expect(confirmation.title == "Delete this child?")
        #expect(confirmation.message == "Test Kid will be removed.")
        #expect(confirmation.confirmButtonTitle == "Delete")
    }

    @Test("archiveThenDelete with one list uses the singular title")
    func archiveOneConfirmation() throws {
        let plan = ChildDeletionPlan.archiveThenDelete(listIds: ["list-secret-1"])
        let confirmation = try #require(ChildrenState.deleteConfirmation(for: makeChild(), plan: plan))
        #expect(confirmation.title == "Archive 1 list and delete this child?")
        #expect(confirmation.message == "Test Kid's active lists will move to Archived and can't be edited afterwards. Archived lists stay available there. This can't be undone.")
        #expect(confirmation.confirmButtonTitle == "Archive and Delete")
    }

    @Test("archiveThenDelete with several lists uses the plural title", arguments: [2, 3, 10])
    func archiveManyConfirmation(count: Int) throws {
        let ids = (1...count).map { "list-secret-\($0)" }
        let confirmation = try #require(
            ChildrenState.deleteConfirmation(for: makeChild(), plan: .archiveThenDelete(listIds: ids))
        )
        #expect(confirmation.title == "Archive \(count) lists and delete this child?")
        #expect(confirmation.message == "Test Kid's active lists will move to Archived and can't be edited afterwards. Archived lists stay available there. This can't be undone.")
        #expect(confirmation.confirmButtonTitle == "Archive and Delete")
    }

    @Test("blocked has no confirmation")
    func blockedHasNoConfirmation() {
        #expect(ChildrenState.deleteConfirmation(for: makeChild(), plan: .blocked) == nil)
    }

    @Test("The blocked message is the plain sentence")
    func blockedMessageText() {
        #expect(ChildrenState.blockedMessage == "An active list of this child can't be archived by you. The person who owns it must archive it first.")
    }

    @Test("The name appears only in the message; no id appears anywhere",
          arguments: [ChildDeletionPlan.deleteNow, .archiveThenDelete(listIds: ["list-secret-1", "list-secret-2"])])
    func confirmationPersonalData(plan: ChildDeletionPlan) throws {
        let confirmation = try #require(ChildrenState.deleteConfirmation(for: makeChild(), plan: plan))
        #expect(confirmation.message.contains("Test Kid"))
        #expect(!confirmation.title.contains("Test Kid"))
        #expect(!confirmation.confirmButtonTitle.contains("Test Kid"))
        for text in [confirmation.title, confirmation.message, confirmation.confirmButtonTitle] {
            #expect(!text.contains("child-secret-7"))
            #expect(!text.contains("list-secret"))
        }
    }

    // MARK: - Banner per result

    @Test("A deleted child and an archived-then-deleted child show no banner")
    func successShowsNoBanner() {
        #expect(ChildrenState.banner(for: .deleted) == nil)
        #expect(ChildrenState.banner(for: .archivedThenDeleted(count: 3)) == nil)
    }

    @Test("A retryable partial failure shows counts only with Try Again and Dismiss")
    func partialFailureRetryable() throws {
        let banner = try #require(
            ChildrenState.banner(for: .partialFailure(archivedCount: 2, totalCount: 3, error: .network))
        )
        #expect(banner.state.message == "Archived 2 of 3 lists. The child was not removed.")
        #expect(banner.state.actions == [.tryAgain, .dismiss])
    }

    @Test("A forbidden partial failure cannot be retried")
    func partialFailureForbidden() throws {
        let banner = try #require(
            ChildrenState.banner(for: .partialFailure(archivedCount: 2, totalCount: 3, error: .forbidden))
        )
        #expect(banner.state.message == "Archived 2 of 3 lists. The child was not removed.")
        #expect(banner.state.actions == [.dismiss])
    }

    @Test("The partial failure message uses the counts it is given")
    func partialFailureCounts() throws {
        let banner = try #require(
            ChildrenState.banner(for: .partialFailure(archivedCount: 0, totalCount: 5, error: .server))
        )
        #expect(banner.state.message == "Archived 0 of 5 lists. The child was not removed.")
    }

    @Test("A partial failure is retryable exactly when its error is", arguments: ChildrenDeleteStateTests.allErrors)
    func partialFailureFollowsPresentation(error: ChildError) throws {
        let banner = try #require(
            ChildrenState.banner(for: .partialFailure(archivedCount: 1, totalCount: 2, error: error))
        )
        let expected: [InlineErrorBannerAction] = ChildErrorPresentation(error).isRetryable
            ? [.tryAgain, .dismiss] : [.dismiss]
        #expect(banner.state.actions == expected)
    }

    @Test("A childHasLists failure shows the corrected message with Dismiss only")
    func failedChildHasLists() throws {
        let banner = try #require(ChildrenState.banner(for: .failed(error: .childHasLists)))
        #expect(banner.state.message == "This child still has active lists. Archive them first.")
        #expect(banner.state.actions == [.dismiss])
    }

    @Test("A server failure shows its message with Try Again and Dismiss")
    func failedServer() throws {
        let banner = try #require(ChildrenState.banner(for: .failed(error: .server)))
        #expect(banner.state.message == ChildError.server.userMessage)
        #expect(banner.state.actions == [.tryAgain, .dismiss])
    }

    @Test("A failed result shows the error message and retries when the error does",
          arguments: ChildrenDeleteStateTests.allErrors)
    func failedFollowsPresentation(error: ChildError) throws {
        let banner = try #require(ChildrenState.banner(for: .failed(error: error)))
        let presentation = ChildErrorPresentation(error)
        #expect(banner.state.message == error.userMessage)
        #expect(banner.state.actions == (presentation.isRetryable ? [.tryAgain, .dismiss] : [.dismiss]))
    }

    @Test("A blocked result shows the blocked message with Dismiss only")
    func blockedBanner() throws {
        let banner = try #require(ChildrenState.banner(for: .blocked))
        #expect(banner.state.message == ChildrenState.blockedMessage)
        #expect(banner.state.actions == [.dismiss])
    }

    @Test("Banners carry no child name or id")
    func bannersCarryNoPersonalData() {
        let results: [ChildDeletionResult] = [
            .partialFailure(archivedCount: 1, totalCount: 2, error: .network),
            .failed(error: .server), .failed(error: .childHasLists), .blocked
        ]
        for result in results {
            let message = ChildrenState.banner(for: result)?.state.message ?? ""
            #expect(!message.contains("Test Kid"))
            #expect(!message.contains("child-secret"))
            #expect(!message.contains("list-secret"))
        }
    }

    // MARK: - Announcements

    @Test("Progress announcements: archiving lists, then deleting the child")
    func progressAnnouncements() {
        #expect(ChildrenState.progressAnnouncement(for: .archiveThenDelete(listIds: ["list-secret-1"])) == "Archiving lists")
        #expect(ChildrenState.progressAnnouncement(for: .deleteNow) == "Deleting child")
    }

    @Test("Result announcements for success")
    func resultAnnouncementsForSuccess() {
        #expect(ChildrenState.resultAnnouncement(for: .deleted) == "Child removed")
        #expect(ChildrenState.resultAnnouncement(for: .archivedThenDeleted(count: 1)) == "Archived 1 list and removed the child")
        #expect(ChildrenState.resultAnnouncement(for: .archivedThenDeleted(count: 3)) == "Archived 3 lists and removed the child")
    }

    @Test("Results the banner announces itself have no result announcement")
    func resultAnnouncementsForBannerResults() {
        #expect(ChildrenState.resultAnnouncement(for: .partialFailure(archivedCount: 1, totalCount: 2, error: .network)) == nil)
        #expect(ChildrenState.resultAnnouncement(for: .failed(error: .server)) == nil)
        #expect(ChildrenState.resultAnnouncement(for: .blocked) == nil)
    }

    @Test("Announcements carry no child name or id")
    func announcementsCarryNoPersonalData() {
        let texts = [
            ChildrenState.progressAnnouncement(for: .archiveThenDelete(listIds: ["list-secret-1"])),
            ChildrenState.progressAnnouncement(for: .deleteNow),
            ChildrenState.resultAnnouncement(for: .deleted) ?? "",
            ChildrenState.resultAnnouncement(for: .archivedThenDeleted(count: 2)) ?? ""
        ]
        for text in texts {
            #expect(!text.contains("Test Kid"))
            #expect(!text.contains("child-secret"))
            #expect(!text.contains("list-secret"))
        }
    }

    // MARK: - Row progress

    @Test("Planning marks only that row as checking, with progress and a checking-lists label")
    func planningRow() throws {
        let state = makeSUT(deletion: ChildDeletionPhaseKind.planning.make(childId: "child-2"))
        let first = try #require(state.rows.first { $0.id == "child-1" })
        let second = try #require(state.rows.first { $0.id == "child-2" })
        #expect(first.status == ChildRowDeletionStatus.none)
        #expect(!first.showsProgress)
        #expect(second.status == ChildRowDeletionStatus.checking)
        #expect(second.showsProgress)
        #expect(second.accessibilityLabel == "\(second.title), \(second.relationshipTitle), checking lists")
        #expect(second.accessibilityLabel == "Dana Dependent, Guardian, checking lists")
        #expect(first.accessibilityLabel == "\(first.title), \(first.relationshipTitle)")
    }

    @Test("Executing marks only that row as removing, with progress and a removing label")
    func executingRow() throws {
        let state = makeSUT(deletion: ChildDeletionPhaseKind.executing.make(childId: "child-2"))
        let first = try #require(state.rows.first { $0.id == "child-1" })
        let second = try #require(state.rows.first { $0.id == "child-2" })
        #expect(first.status == ChildRowDeletionStatus.none)
        #expect(!first.showsProgress)
        #expect(second.status == ChildRowDeletionStatus.removing)
        #expect(second.showsProgress)
        #expect(second.accessibilityLabel == "\(second.title), \(second.relationshipTitle), removing")
        #expect(second.accessibilityLabel == "Dana Dependent, Guardian, removing")
        #expect(first.accessibilityLabel == "\(first.title), \(first.relationshipTitle)")
    }

    @Test("Confirming marks no row: no status, no spinner, plain labels")
    func confirmingRow() {
        let state = makeSUT(deletion: ChildDeletionPhaseKind.confirming.make(childId: "child-2"))
        for row in state.rows {
            #expect(row.status == ChildRowDeletionStatus.none)
            #expect(!row.showsProgress)
            #expect(row.accessibilityLabel == "\(row.title), \(row.relationshipTitle)")
        }
    }

    @Test("Nobody is deleting by default or when idle")
    func nobodyDeleting() {
        #expect(makeSUT(deletion: .idle).rows.allSatisfy { $0.status == ChildRowDeletionStatus.none && !$0.showsProgress })
        let byDefault = ChildrenState(children: ChildFixtures.twoChildren(), phase: .loaded)
        #expect(byDefault.rows.allSatisfy { $0.status == ChildRowDeletionStatus.none && !$0.showsProgress })
    }

    @Test("A deletion for an id that matches no row marks no row",
          arguments: [ChildDeletionPhaseKind.planning, ChildDeletionPhaseKind.executing, ChildDeletionPhaseKind.confirming])
    func unknownDeletingId(kind: ChildDeletionPhaseKind) {
        let state = makeSUT(deletion: kind.make(childId: "child-unknown"))
        #expect(state.rows.allSatisfy { $0.status == ChildRowDeletionStatus.none && !$0.showsProgress })
    }

    @Test("showsProgress is true only for checking and removing",
          arguments: [
            (ChildDeletionPhaseKind.idle, false),
            (ChildDeletionPhaseKind.planning, true),
            (ChildDeletionPhaseKind.confirming, false),
            (ChildDeletionPhaseKind.executing, true)
          ])
    func showsProgressTable(kind: ChildDeletionPhaseKind, expected: Bool) throws {
        let state = makeSUT(deletion: kind.make(childId: "child-1"))
        let row = try #require(state.rows.first { $0.id == "child-1" })
        #expect(row.showsProgress == expected)
    }

    @Test("Row labels never contain the id in any phase", arguments: ChildDeletionPhaseKind.allCases)
    func labelsHaveNoId(kind: ChildDeletionPhaseKind) {
        for row in makeSUT(deletion: kind.make(childId: "child-1")).rows {
            #expect(!row.accessibilityLabel.contains(row.id))
        }
    }

    // MARK: - Announcements for the plan step and Try Again

    @Test("The planning announcement is the plain Checking lists text")
    func planningAnnouncementText() {
        #expect(ChildrenState.planningAnnouncement == "Checking lists")
    }

    @Test("retryAnnouncement equals the progress announcement of the recomputed plan")
    func retryAnnouncementFollowsPlan() {
        let archive = ChildDeletionPlan.archiveThenDelete(listIds: ["list-secret-1", "list-secret-2"])
        #expect(ChildrenState.retryAnnouncement(for: archive) == ChildrenState.progressAnnouncement(for: archive))
        #expect(ChildrenState.retryAnnouncement(for: archive) == "Archiving lists")
        #expect(ChildrenState.retryAnnouncement(for: .deleteNow) == ChildrenState.progressAnnouncement(for: .deleteNow))
    }

    @Test("retryAnnouncement is not always Archiving lists: deleteNow says Deleting child")
    func retryAnnouncementDeleteNow() {
        #expect(ChildrenState.retryAnnouncement(for: .deleteNow) == "Deleting child")
        #expect(ChildrenState.retryAnnouncement(for: .deleteNow) != "Archiving lists")
    }

    @Test("The planning and retry announcements carry no name or id")
    func newAnnouncementsCarryNoPersonalData() {
        let texts = [
            ChildrenState.planningAnnouncement,
            ChildrenState.retryAnnouncement(for: .deleteNow) ?? "",
            ChildrenState.retryAnnouncement(for: .archiveThenDelete(listIds: ["list-secret-1"])) ?? ""
        ]
        for text in texts {
            #expect(!text.isEmpty)
            #expect(!text.contains("Test Kid"))
            #expect(!text.contains("child-secret"))
            #expect(!text.contains("list-secret"))
        }
    }

    // MARK: - Control gating

    @Test("Delete controls are enabled only when idle and not mutating (every phase times isMutating)",
          arguments: [
            (ChildDeletionPhaseKind.idle, false, true),
            (ChildDeletionPhaseKind.idle, true, false),
            (ChildDeletionPhaseKind.planning, false, false),
            (ChildDeletionPhaseKind.planning, true, false),
            (ChildDeletionPhaseKind.confirming, false, false),
            (ChildDeletionPhaseKind.confirming, true, false),
            (ChildDeletionPhaseKind.executing, false, false),
            (ChildDeletionPhaseKind.executing, true, false)
          ])
    func deleteControlsEnabled(kind: ChildDeletionPhaseKind, isMutating: Bool, expected: Bool) {
        let deletion = kind.make()
        #expect(ChildrenState.deleteControlsEnabled(isMutating: isMutating, deletion: deletion) == expected)
    }
}
