//
//  MembersOwnerRowsTests.swift
//  ChristmasTrackerTests
//
//  Story I3d-D1: the Members section shows the owner and co-owner from the detail's own fields,
//  then the roster. A truth table over the flags, members present or absent and every roster
//  shape, plus focused tests for the visibility, filtering, duplicate and accessibility rules.
//
//  Oracle (written here from the contract, not computed with the production rule): when the
//  roster is shown, rows are [owner, co-owner if present, then the ACTIVE members and viewers],
//  and a roster entry for the owner or co-owner is shown once, as the owner or co-owner row.
//  When it is not shown, rows are empty.
//

import Testing
import Foundation
@testable import ChristmasTracker

@Suite("Members owner rows Tests")
struct MembersOwnerRowsTests {

    // MARK: - Roster shapes

    /// One roster shape: whether the list has a co-owner and what the wire roster contains.
    nonisolated struct Shape: Sendable, CustomTestStringConvertible {
        let name: String
        let hasCoOwner: Bool
        /// The roster holds members and viewers (otherwise it is empty).
        let hasMembers: Bool
        let duplicatesOwner: Bool
        let duplicatesCoOwner: Bool

        var testDescription: String { name }

        func roster() -> [ListFixtures.MemberSpec] {
            guard hasMembers else { return [] }
            var rows: [ListFixtures.MemberSpec] = []
            if duplicatesOwner { rows.append(MembersFixtures.ownerRow()) }
            rows.append(MembersFixtures.memberRow())
            if duplicatesCoOwner { rows.append(MembersFixtures.coOwnerRow()) }
            rows.append(MembersFixtures.viewerRow())
            rows += MembersFixtures.inactiveRows()
            return rows
        }

        /// The kinds that must show when the roster is shown, spelled out by construction.
        var expectedKinds: [MemberRowKind] {
            var kinds: [MemberRowKind] = [.owner]
            if hasCoOwner { kinds.append(.coOwner) }
            if hasMembers { kinds += [.member, .viewer] }
            return kinds
        }

        var expectedUserIds: [String] {
            var ids = [MembersFixtures.ownerId]
            if hasCoOwner { ids.append(MembersFixtures.coOwnerId) }
            if hasMembers { ids += [MembersFixtures.memberUserId, MembersFixtures.viewerUserId] }
            return ids
        }
    }

    nonisolated static let shapes: [Shape] = [
        Shape(name: "empty roster, no co-owner", hasCoOwner: false, hasMembers: false, duplicatesOwner: false, duplicatesCoOwner: false),
        Shape(name: "empty roster, co-owner", hasCoOwner: true, hasMembers: false, duplicatesOwner: false, duplicatesCoOwner: false),
        Shape(name: "owner only plus members and viewers", hasCoOwner: false, hasMembers: true, duplicatesOwner: false, duplicatesCoOwner: false),
        Shape(name: "owner and co-owner plus members and viewers", hasCoOwner: true, hasMembers: true, duplicatesOwner: false, duplicatesCoOwner: false),
        Shape(name: "roster contains the owner (no co-owner)", hasCoOwner: false, hasMembers: true, duplicatesOwner: true, duplicatesCoOwner: false),
        Shape(name: "roster contains the owner (co-owner present)", hasCoOwner: true, hasMembers: true, duplicatesOwner: true, duplicatesCoOwner: false),
        Shape(name: "roster contains the co-owner", hasCoOwner: true, hasMembers: true, duplicatesOwner: false, duplicatesCoOwner: true),
        Shape(name: "roster contains both the owner and the co-owner", hasCoOwner: true, hasMembers: true, duplicatesOwner: true, duplicatesCoOwner: true)
    ]

    /// One truth-table case: three flags x members present/absent x roster shape (128 cases).
    nonisolated struct Case: Sendable, CustomTestStringConvertible {
        let canSeeMembers: Bool
        let canManageMembers: Bool
        let canLeaveList: Bool
        let membersPresent: Bool
        let shape: Shape

        var testDescription: String {
            "see \(canSeeMembers) manage \(canManageMembers) leave \(canLeaveList) present \(membersPresent) / \(shape.name)"
        }
    }

    nonisolated static let cases: [Case] = {
        var all: [Case] = []
        for see in [true, false] {
            for manage in [true, false] {
                for leave in [true, false] {
                    for present in [true, false] {
                        for shape in shapes {
                            all.append(Case(
                                canSeeMembers: see, canManageMembers: manage, canLeaveList: leave,
                                membersPresent: present, shape: shape
                            ))
                        }
                    }
                }
            }
        }
        return all
    }()

    // MARK: - Factory

    private func makeSUT(
        canSeeMembers: Bool = true,
        canManageMembers: Bool = true,
        canLeaveList: Bool = false,
        roster: [ListFixtures.MemberSpec]? = MembersFixtures.memberRoster(),
        hasCoOwner: Bool = true,
        memberCount: Int = 3
    ) throws -> MembersSectionState {
        let flags = MembersFixtures.SectionFlags(
            canSeeMembers: canSeeMembers, canManageMembers: canManageMembers,
            canLeaveList: canLeaveList, canSetCoOwner: false
        )
        return MembersSectionState(
            detail: try MembersFixtures.detail(
                flags: flags, roster: roster, hasCoOwner: hasCoOwner, memberCount: memberCount
            )
        )
    }

    // MARK: - Truth table

    @Test("Truth table: flags x members present/absent x every roster shape", arguments: MembersOwnerRowsTests.cases)
    func truthTable(testCase: Case) throws {
        let shape = testCase.shape
        let state = try makeSUT(
            canSeeMembers: testCase.canSeeMembers,
            canManageMembers: testCase.canManageMembers,
            canLeaveList: testCase.canLeaveList,
            roster: testCase.membersPresent ? shape.roster() : nil,
            hasCoOwner: shape.hasCoOwner
        )
        let expectRoster = testCase.canSeeMembers && testCase.membersPresent

        #expect(state.showsRoster == expectRoster)
        #expect(state.showsAdd == testCase.canManageMembers)
        #expect(state.showsLeave == testCase.canLeaveList)
        #expect(state.memberCountText == "3 members")

        guard expectRoster else {
            #expect(state.rows.isEmpty)
            #expect(!state.rows.contains { $0.kind == .owner || $0.kind == .coOwner })
            return
        }

        #expect(state.rows.map(\.kind) == shape.expectedKinds)
        #expect(state.rows.map(\.userId) == shape.expectedUserIds)
        #expect(Set(state.rows.map(\.userId)).count == state.rows.count)
        #expect(Set(state.rows.map(\.id)).count == state.rows.count)
        #expect(state.rows.map(\.roleLabel) == shape.expectedKinds.map(\.title))
        for row in state.rows {
            let isRosterKind = row.kind == .member || row.kind == .viewer
            #expect(row.canRemove == (isRosterKind && testCase.canManageMembers))
        }
        #expect(state.rows.first?.displayName == MembersFixtures.ownerName)
        if shape.hasCoOwner {
            #expect(state.rows.dropFirst().first?.displayName == MembersFixtures.coOwnerName)
        }
    }

    // MARK: - Focused tests

    @Test("Owner then co-owner rows come first, from the detail, labeled and never removable")
    func ownerRowsFirst() throws {
        let state = try makeSUT()
        let owner = try #require(state.rows.first)
        let coOwner = try #require(state.rows.dropFirst().first)
        #expect(owner.kind == .owner)
        #expect(owner.roleLabel == "Owner")
        #expect(owner.displayName == MembersFixtures.ownerName)
        #expect(owner.userId == MembersFixtures.ownerId)
        #expect(!owner.canRemove)
        #expect(coOwner.kind == .coOwner)
        #expect(coOwner.roleLabel == "Co-owner")
        #expect(coOwner.displayName == MembersFixtures.coOwnerName)
        #expect(coOwner.userId == MembersFixtures.coOwnerId)
        #expect(!coOwner.canRemove)
        #expect(state.rows.map(\.kind) == [.owner, .coOwner, .member, .viewer])
    }

    @Test("Without a co-owner there is no co-owner row")
    func noCoOwnerRow() throws {
        let state = try makeSUT(hasCoOwner: false)
        #expect(state.rows.map(\.kind) == [.owner, .member, .viewer])
    }

    @Test("Owner and co-owner row ids are distinct from each other and from every membership id")
    func ownerRowIdsAreDistinct() throws {
        let state = try makeSUT(roster: MembersFixtures.fullRoster())
        let owner = try #require(state.rows.first { $0.kind == .owner })
        let coOwner = try #require(state.rows.first { $0.kind == .coOwner })
        #expect(owner.id != coOwner.id)
        let membershipIds = (MembersFixtures.fullRoster()).map(\.id)
        #expect(!membershipIds.contains(owner.id))
        #expect(!membershipIds.contains(coOwner.id))
        #expect(Set(state.rows.map(\.id)).count == state.rows.count)
    }

    @Test("Owner and co-owner row ids are stable across builds")
    func ownerRowIdsAreStable() throws {
        let first = try makeSUT()
        let second = try makeSUT()
        #expect(first.rows.map(\.id) == second.rows.map(\.id))
    }

    @Test("The accessibility label of the owner and co-owner rows is name, then role")
    func ownerAccessibilityLabels() throws {
        let state = try makeSUT()
        let owner = try #require(state.rows.first { $0.kind == .owner })
        let coOwner = try #require(state.rows.first { $0.kind == .coOwner })
        #expect(owner.accessibilityLabel == "\(MembersFixtures.ownerName), Owner")
        #expect(coOwner.accessibilityLabel == "\(MembersFixtures.coOwnerName), Co-owner")
    }

    // MARK: - Never revealed without the roster

    @Test("Owner and co-owner rows never appear when the roster is not shown")
    func noOwnerRowsWithoutRoster() throws {
        // canSeeMembers false with members absent.
        let hiddenAbsent = try makeSUT(canSeeMembers: false, canManageMembers: false, canLeaveList: true, roster: nil)
        // canSeeMembers false even though a members array is in the model.
        let hiddenPresent = try makeSUT(
            canSeeMembers: false, canManageMembers: false, canLeaveList: true, roster: MembersFixtures.memberRoster()
        )
        // canSeeMembers true but no members array.
        let visibleAbsent = try makeSUT(canSeeMembers: true, roster: nil)
        for state in [hiddenAbsent, hiddenPresent, visibleAbsent] {
            #expect(!state.showsRoster)
            #expect(state.rows.isEmpty)
            #expect(state.memberCountText == "3 members")
        }
        #expect(hiddenAbsent.showsLeave)
        #expect(visibleAbsent.showsAdd)
    }

    @Test("Without a co-owner, a hidden roster still reveals no owner row")
    func noOwnerRowWithoutRosterOrCoOwner() throws {
        let state = try makeSUT(canSeeMembers: false, roster: MembersFixtures.memberRoster(), hasCoOwner: false)
        #expect(state.rows.isEmpty)
    }

    // MARK: - Inactive entries and the empty roster

    @Test("INVITED, REMOVED and EXPIRED entries are still not shown")
    func inactiveStillHidden() throws {
        let state = try makeSUT(roster: MembersFixtures.memberRoster(includeInactive: true))
        let ids = state.rows.map(\.id)
        for hidden in ["mem-inv", "mem-rem", "mem-exp"] {
            #expect(!ids.contains(hidden))
        }
        #expect(state.rows.map(\.kind) == [.owner, .coOwner, .member, .viewer])
    }

    @Test("An empty roster still shows the owner row, and the co-owner row if present")
    func emptyRosterShowsOwnerRows() throws {
        let withCoOwner = try makeSUT(roster: [])
        #expect(withCoOwner.showsRoster)
        #expect(withCoOwner.rows.map(\.kind) == [.owner, .coOwner])
        let withoutCoOwner = try makeSUT(roster: [], hasCoOwner: false)
        #expect(withoutCoOwner.showsRoster)
        #expect(withoutCoOwner.rows.map(\.kind) == [.owner])
    }

    // MARK: - Duplicates

    @Test("A roster entry for the owner is shown once, as the owner, with no Remove")
    func duplicateOwnerShownOnce() throws {
        let roster = [MembersFixtures.ownerRow(), MembersFixtures.memberRow()]
        let state = try makeSUT(roster: roster, hasCoOwner: false)
        #expect(state.rows.filter { $0.userId == MembersFixtures.ownerId }.count == 1)
        #expect(state.rows.map(\.kind) == [.owner, .member])
        #expect(state.rows.map(\.canRemove) == [false, true])
        #expect(!state.rows.map(\.id).contains("mem-owner"))
    }

    @Test("A roster entry for the co-owner is shown once, as the co-owner, with no Remove")
    func duplicateCoOwnerShownOnce() throws {
        let roster = [MembersFixtures.memberRow(), MembersFixtures.coOwnerRow()]
        let state = try makeSUT(roster: roster)
        #expect(state.rows.filter { $0.userId == MembersFixtures.coOwnerId }.count == 1)
        #expect(state.rows.map(\.kind) == [.owner, .coOwner, .member])
        #expect(state.rows.map(\.canRemove) == [false, false, true])
        #expect(!state.rows.map(\.id).contains("mem-co"))
    }

    @Test("A roster holding both the owner and the co-owner shows each once")
    func duplicateBothShownOnce() throws {
        let state = try makeSUT(roster: MembersFixtures.fullRoster())
        #expect(state.rows.map(\.kind) == [.owner, .coOwner, .member, .viewer])
        #expect(Set(state.rows.map(\.userId)).count == state.rows.count)
        #expect(state.rows.map(\.canRemove) == [false, false, true, true])
    }
}
