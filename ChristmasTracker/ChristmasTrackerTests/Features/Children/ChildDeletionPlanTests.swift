//
//  ChildDeletionPlanTests.swift
//  ChristmasTrackerTests
//
//  Story I3d-D2: the pure child-deletion plan. One truth table covers which lists count (the
//  child's own ACTIVE and DRAFT lists only) and what the plan is.
//
//  Fake ids and names only.
//

import Foundation
import Testing
@testable import ChristmasTracker

/// One row of the plan truth table.
nonisolated struct ChildDeletionPlanCase: Sendable, CustomTestStringConvertible {
    let name: String
    let childId: String
    let lists: [GiftList]
    let expected: ChildDeletionPlan

    var testDescription: String { name }
}

nonisolated enum ChildDeletionPlanFixtures {
    static let childId = "child-1"

    /// A list for `recipientId` with the given status and delete flag.
    static func list(
        _ id: String,
        _ status: ListStatus = .active,
        canDelete: Bool = true,
        recipientId: String = ChildDeletionPlanFixtures.childId
    ) -> GiftList {
        ListFixtures.giftList(
            id: id,
            status: status,
            flags: ListFixtures.Flags(canCreateItem: true, canDeleteList: canDelete),
            recipient: ListPerson(id: recipientId, displayName: "Name of \(recipientId)")
        )
    }

    static let cases: [ChildDeletionPlanCase] = [
        ChildDeletionPlanCase(
            name: "no lists at all is deleteNow",
            childId: childId, lists: [], expected: .deleteNow
        ),
        ChildDeletionPlanCase(
            name: "only archived lists is deleteNow",
            childId: childId,
            lists: [list("a", .archived, canDelete: false), list("b", .archived, canDelete: false)],
            expected: .deleteNow
        ),
        ChildDeletionPlanCase(
            name: "one active list is archiveThenDelete",
            childId: childId, lists: [list("a")], expected: .archiveThenDelete(listIds: ["a"])
        ),
        ChildDeletionPlanCase(
            name: "several active lists keep the order of the input",
            childId: childId,
            lists: [list("c"), list("a"), list("b")],
            expected: .archiveThenDelete(listIds: ["c", "a", "b"])
        ),
        ChildDeletionPlanCase(
            name: "a draft counts as active",
            childId: childId,
            lists: [list("a", .draft)],
            expected: .archiveThenDelete(listIds: ["a"])
        ),
        ChildDeletionPlanCase(
            name: "active, draft and archived mix: only active and draft are planned, in order",
            childId: childId,
            lists: [list("a"), list("x", .archived), list("d", .draft), list("y", .archived)],
            expected: .archiveThenDelete(listIds: ["a", "d"])
        ),
        ChildDeletionPlanCase(
            name: "one active list the user cannot delete is blocked",
            childId: childId, lists: [list("a", canDelete: false)], expected: .blocked
        ),
        ChildDeletionPlanCase(
            name: "a draft the user cannot delete is blocked",
            childId: childId, lists: [list("a", .draft, canDelete: false)], expected: .blocked
        ),
        ChildDeletionPlanCase(
            name: "a mix of deletable and non-deletable active lists is blocked",
            childId: childId,
            lists: [list("a"), list("b", canDelete: false), list("c")],
            expected: .blocked
        ),
        ChildDeletionPlanCase(
            name: "an archived list that cannot be deleted does not block",
            childId: childId,
            lists: [list("a"), list("x", .archived, canDelete: false)],
            expected: .archiveThenDelete(listIds: ["a"])
        ),
        ChildDeletionPlanCase(
            name: "lists of other children never count",
            childId: childId,
            lists: [list("o1", recipientId: "child-2"), list("o2", .draft, recipientId: "child-3")],
            expected: .deleteNow
        ),
        ChildDeletionPlanCase(
            name: "a non-deletable list of another child does not block",
            childId: childId,
            lists: [list("a"), list("o1", canDelete: false, recipientId: "child-2")],
            expected: .archiveThenDelete(listIds: ["a"])
        ),
        ChildDeletionPlanCase(
            name: "the signed-in user's own lists never count",
            childId: childId,
            lists: [
                ListFixtures.giftList(id: "mine-1", flags: ListFixtures.Flags(isRecipient: true, canDeleteList: false)),
                ListFixtures.giftList(id: "mine-2", status: .draft, flags: ListFixtures.Flags(isRecipient: true, canDeleteList: true))
            ],
            expected: .deleteNow
        ),
        ChildDeletionPlanCase(
            name: "the child's lists are picked out of a mixed input, in order",
            childId: childId,
            lists: [
                list("o1", recipientId: "child-2"),
                list("a"),
                ListFixtures.giftList(id: "mine-1", flags: ListFixtures.Flags(isRecipient: true)),
                list("b", .draft)
            ],
            expected: .archiveThenDelete(listIds: ["a", "b"])
        ),
        ChildDeletionPlanCase(
            name: "an empty child id matches none of the lists",
            childId: "",
            lists: [list("a"), list("b", .draft, canDelete: false)],
            expected: .deleteNow
        )
    ]
}

@Suite("ChildDeletionPlan", .timeLimit(.minutes(1)))
struct ChildDeletionPlanTests {

    @Test("the plan truth table", arguments: ChildDeletionPlanFixtures.cases)
    func truthTable(row: ChildDeletionPlanCase) {
        let plan = ChildDeletionPlan.plan(childId: row.childId, lists: row.lists)

        #expect(plan == row.expected)
    }
}
