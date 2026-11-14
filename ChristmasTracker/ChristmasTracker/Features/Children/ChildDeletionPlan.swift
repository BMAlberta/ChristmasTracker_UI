//
//  ChildDeletionPlan.swift
//  ChristmasTracker
//
//  The pure plan for deleting a child (decision L17): the server refuses while any of the child's
//  lists is ACTIVE or DRAFT, so the client archives those first. Archived lists never count.
//

import Foundation

nonisolated enum ChildDeletionPlan: Equatable, Sendable {
    /// The child has no active list: delete it right away.
    case deleteNow
    /// Archive these lists in this order, then delete the child.
    case archiveThenDelete(listIds: [String])
    /// An active list of the child cannot be archived by the signed-in user.
    case blocked

    static func plan(childId: String, lists: [GiftList]) -> ChildDeletionPlan {
        let active = lists.filter { $0.recipient.id == childId && ListSegment.active.includes($0.status) }
        if active.isEmpty { return .deleteNow }
        if active.contains(where: { !$0.capabilities.canDeleteList }) { return .blocked }
        return .archiveThenDelete(listIds: active.map(\.id))
    }

    /// The list ids this plan would archive (empty for deleteNow and blocked).
    var archiveListIds: [String] {
        switch self {
        case .archiveThenDelete(let listIds): listIds
        case .deleteNow, .blocked: []
        }
    }

    /// true when this plan would archive any list id that is not in `confirmed.archiveListIds`.
    func hasUnconfirmedLists(comparedTo confirmed: ChildDeletionPlan) -> Bool {
        let confirmedIds = Set(confirmed.archiveListIds)
        return archiveListIds.contains { !confirmedIds.contains($0) }
    }
}
