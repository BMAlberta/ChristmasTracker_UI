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
}
