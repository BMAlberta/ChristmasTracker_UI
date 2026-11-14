//
//  ChildDeletionFlowHarness.swift
//  ChristmasTrackerTests
//
//  Story I3d-D2: the shared setup for the ChildDeletionFlow tests. Real ChildService and
//  ListService over the gated repository fakes, so the services' own session guards apply.
//  Fake ids and names only.
//

import Foundation
@testable import ChristmasTracker

@MainActor
struct ChildDeletionFlowHarness {
    static let childId = "child-1"

    let flow: ChildDeletionFlow
    let childService: ChildService
    let listService: ListService
    let childRepo: GatedChildRepository
    let listRepo: GatedListRepository
    let store: ListDataStore

    /// Builds the flow. The child service already holds the two fixture children.
    static func make(honorsCancellation: Bool = false) async -> ChildDeletionFlowHarness {
        let childRepo = GatedChildRepository()
        childRepo.honorsCancellation = honorsCancellation
        let listRepo = GatedListRepository()
        listRepo.honorsCancellation = honorsCancellation
        let store = ListDataStore()
        let childService = ChildService(repository: childRepo)
        let listService = ListService(repository: listRepo, dataStore: store)
        childRepo.enqueueFetchChildren(.success(ChildFixtures.twoChildren()))
        await childService.loadChildren()
        return ChildDeletionFlowHarness(
            flow: ChildDeletionFlow(childService: childService, listService: listService),
            childService: childService,
            listService: listService,
            childRepo: childRepo,
            listRepo: listRepo,
            store: store
        )
    }

    /// A deletable list of the child under test.
    static func childList(_ id: String, _ status: ListStatus = .active, canDelete: Bool = true) -> GiftList {
        ListFixtures.giftList(
            id: id,
            status: status,
            flags: ListFixtures.Flags(canCreateItem: true, canDeleteList: canDelete),
            recipient: ListPerson(id: childId, displayName: "Name of \(childId)")
        )
    }

    /// The same list as the server shows it after the archive.
    static func archivedChildList(_ id: String) -> GiftList {
        childList(id, .archived, canDelete: false)
    }

    /// Nothing the flow may publish. REWRITTEN (UX1a U2): the shared `error` properties are gone, so
    /// this now means: the child load channel is not failed and neither list load failure is set.
    var sharedErrorsAreNil: Bool {
        if case .failed = childService.phase { return false }
        return listService.listsLoadFailure == nil && listService.detailLoadFailure == nil
    }
}
