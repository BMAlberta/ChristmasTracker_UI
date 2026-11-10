//
//  MembersTruthTableTests.swift
//  ChristmasTrackerTests
//
//  Story I3b-M1: the truth table for MembersSectionState and CoOwnerSectionState.
//
//  Reduction. Both states depend on exactly four capability flags (canSeeMembers,
//  canManageMembers, canLeaveList, canSetCoOwner), on whether the detail carries a `members`
//  array, on whether the list has a co-owner, and on the kind of each roster row (owner,
//  co-owner, member, viewer; kind comes from the person ids and the row role, never from the
//  viewer's role). The other eight flags and myRole do not take part, so they are left false
//  and myRole is varied inside the exhaustive test to prove it.
//
//  Test 1 enumerates 2^4 flag combinations x members present/absent x co-owner present/absent
//  (64 cases) against an oracle written here from the privacy matrix and the guide's flag
//  table, with the expected rows spelled out by construction (the roster order is known), not
//  recomputed with the production rule. Test 2 pins seven named personas with their guide flag
//  sets and the full expected outcome. One parameterized test counts as one test each.
//

import Testing
import Foundation
@testable import ChristmasTracker

@Suite("Members truth table Tests")
struct MembersTruthTableTests {

    // MARK: - Exhaustive enumeration against an independent oracle

    @Test("All 16 flag combinations x members present/absent x co-owner present/absent")
    func exhaustiveTruthTable() throws {
        var checked = 0
        for bits in 0..<16 {
            for membersPresent in [true, false] {
                for hasCoOwner in [true, false] {
                    let flags = MembersFixtures.sectionFlags(bits: bits)
                    let roster = membersPresent ? MembersFixtures.fullRoster(includeCoOwner: hasCoOwner) : nil
                    // myRole is varied with the case index; it must make no difference.
                    let myRole = ["owner", "co-owner", "member", "viewer"][checked % 4]
                    let detail = try MembersFixtures.detail(
                        flags: flags, roster: roster, hasCoOwner: hasCoOwner, memberCount: 3, myRole: myRole
                    )
                    let members = MembersSectionState(detail: detail)
                    let coOwner = CoOwnerSectionState(detail: detail)
                    let label = "bits \(bits) present \(membersPresent) coOwner \(hasCoOwner)"

                    // Oracle: written from the guide's flag table.
                    let expectRoster = flags.canSeeMembers && membersPresent
                    let expectKinds: [MemberRowKind] = hasCoOwner
                        ? [.owner, .coOwner, .member, .viewer]
                        : [.owner, .member, .viewer]
                    let expectRemovable: [Bool] = hasCoOwner
                        ? [false, false, flags.canManageMembers, flags.canManageMembers]
                        : [false, flags.canManageMembers, flags.canManageMembers]

                    #expect(members.showsRoster == expectRoster, "showsRoster \(label)")
                    #expect(members.showsAdd == flags.canManageMembers, "showsAdd \(label)")
                    #expect(members.showsLeave == flags.canLeaveList, "showsLeave \(label)")
                    #expect(members.memberCountText == "3 members", "count \(label)")
                    if expectRoster {
                        #expect(members.rows.map(\.kind) == expectKinds, "kinds \(label)")
                        #expect(members.rows.map(\.canRemove) == expectRemovable, "canRemove \(label)")
                    } else {
                        #expect(members.rows.isEmpty, "rows \(label)")
                    }

                    #expect(coOwner.showsChange == flags.canSetCoOwner, "showsChange \(label)")
                    // Clearing is not possible through the generated client today.
                    #expect(coOwner.showsRemove == false, "showsRemove \(label)")
                    #expect(
                        coOwner.currentCoOwnerName == (hasCoOwner ? MembersFixtures.coOwnerName : nil),
                        "coOwner name \(label)"
                    )
                    checked += 1
                }
            }
        }
        #expect(checked == 64)
    }

    // MARK: - Named personas

    /// A viewer persona with its guide flag set and the full expected outcome.
    nonisolated struct Persona: Sendable, CustomTestStringConvertible {
        let name: String
        let flags: MembersFixtures.SectionFlags
        let membersPresent: Bool
        let status: String
        let visibility: String
        let myRole: String
        let showsRoster: Bool
        let showsAdd: Bool
        /// canRemove for the rows owner, co-owner, member, viewer (only checked when the roster shows).
        let removable: [Bool]
        let showsLeave: Bool
        let showsChange: Bool
        let showsRemove: Bool
        let memberCountText: String

        var testDescription: String { name }
    }

    nonisolated private static func flags(_ see: Bool, _ manage: Bool, _ setCoOwner: Bool, _ leave: Bool) -> MembersFixtures.SectionFlags {
        MembersFixtures.SectionFlags(
            canSeeMembers: see, canManageMembers: manage, canLeaveList: leave, canSetCoOwner: setCoOwner
        )
    }

    /// Flags are (see, manage, setCoOwner, leave) exactly as the guide lists them.
    nonisolated static let personas: [Persona] = [
        Persona(
            name: "owner / recipient of a self list (blind owner)",
            flags: flags(true, true, true, false), membersPresent: true, status: "ACTIVE",
            visibility: "PRIVATE", myRole: "owner",
            showsRoster: true, showsAdd: true, removable: [false, false, true, true],
            showsLeave: false, showsChange: true, showsRemove: false, memberCountText: "4 members"
        ),
        Persona(
            name: "co-owner",
            flags: flags(true, true, false, false), membersPresent: true, status: "ACTIVE",
            visibility: "PRIVATE", myRole: "co-owner",
            showsRoster: true, showsAdd: true, removable: [false, false, true, true],
            showsLeave: false, showsChange: false, showsRemove: false, memberCountText: "4 members"
        ),
        Persona(
            name: "blind co-owner",
            flags: flags(true, true, false, false), membersPresent: true, status: "ACTIVE",
            visibility: "PRIVATE", myRole: "co-owner",
            showsRoster: true, showsAdd: true, removable: [false, false, true, true],
            showsLeave: false, showsChange: false, showsRemove: false, memberCountText: "4 members"
        ),
        Persona(
            name: "MEMBER-role member",
            flags: flags(true, false, false, true), membersPresent: true, status: "ACTIVE",
            visibility: "PRIVATE", myRole: "member",
            showsRoster: true, showsAdd: false, removable: [false, false, false, false],
            showsLeave: true, showsChange: false, showsRemove: false, memberCountText: "4 members"
        ),
        Persona(
            name: "VIEWER-role member",
            flags: flags(false, false, false, true), membersPresent: false, status: "ACTIVE",
            visibility: "PRIVATE", myRole: "viewer",
            showsRoster: false, showsAdd: false, removable: [],
            showsLeave: true, showsChange: false, showsRemove: false, memberCountText: "4 members"
        ),
        Persona(
            name: "PUBLIC non-member",
            flags: flags(false, false, false, false), membersPresent: false, status: "ACTIVE",
            visibility: "PUBLIC", myRole: "viewer",
            showsRoster: false, showsAdd: false, removable: [],
            showsLeave: false, showsChange: false, showsRemove: false, memberCountText: "4 members"
        ),
        Persona(
            name: "archived list (manage and set co-owner off, leave on, roster visible)",
            flags: flags(true, false, false, true), membersPresent: true, status: "ARCHIVED",
            visibility: "PRIVATE", myRole: "member",
            showsRoster: true, showsAdd: false, removable: [false, false, false, false],
            showsLeave: true, showsChange: false, showsRemove: false, memberCountText: "4 members"
        )
    ]

    @Test("Seven personas show exactly what their flags allow", arguments: MembersTruthTableTests.personas)
    func personaOutcome(persona: Persona) throws {
        let roster = persona.membersPresent ? MembersFixtures.fullRoster() : nil
        let detail = try MembersFixtures.detail(
            flags: persona.flags, roster: roster, memberCount: 4,
            status: persona.status, visibility: persona.visibility, myRole: persona.myRole
        )
        let members = MembersSectionState(detail: detail)
        let coOwner = CoOwnerSectionState(detail: detail)

        #expect(members.showsRoster == persona.showsRoster)
        #expect(members.showsAdd == persona.showsAdd)
        #expect(members.showsLeave == persona.showsLeave)
        #expect(members.memberCountText == persona.memberCountText)
        #expect(coOwner.showsChange == persona.showsChange)
        #expect(coOwner.showsRemove == persona.showsRemove)

        if persona.showsRoster {
            #expect(members.rows.map(\.kind) == [.owner, .coOwner, .member, .viewer])
            #expect(members.rows.map(\.canRemove) == persona.removable)
            // Owner and co-owner rows are never removable, whoever is looking.
            #expect(members.rows.filter { $0.kind == .owner || $0.kind == .coOwner }.allSatisfy { !$0.canRemove })
        } else {
            #expect(members.rows.isEmpty)
        }
    }

    @Test("Roster presence for a persona is never granted by the model alone")
    func modelAloneDoesNotGrantRoster() throws {
        // A roster in the model with canSeeMembers false (viewer, PUBLIC non-member) stays hidden.
        for flags in [Self.flags(false, false, false, true), Self.flags(false, false, false, false)] {
            let detail = try MembersFixtures.detail(flags: flags, roster: MembersFixtures.fullRoster())
            let state = MembersSectionState(detail: detail)
            #expect(!state.showsRoster)
            #expect(state.rows.isEmpty)
        }
    }
}
