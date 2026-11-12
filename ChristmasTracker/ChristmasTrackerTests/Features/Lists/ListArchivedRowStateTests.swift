//
//  ListArchivedRowStateTests.swift
//  ChristmasTrackerTests
//
//  Story I3c-A: ListRowState for ARCHIVED lists, per persona, driven by flags only. The server
//  sends the four management flags false on an archived list and leaves the item flags alone; the
//  row shows the Archived badge and offers no delete (archive) action. Fake data only.
//

import Testing
import Foundation
@testable import ChristmasTracker

@Suite("List archived row state Tests")
struct ListArchivedRowStateTests {

    // MARK: - Personas

    enum Persona: CaseIterable, Sendable, CustomTestStringConvertible {
        case owner, coOwner, blindOwner, memberRole, viewerRole, publicNonMember

        var testDescription: String {
            switch self {
            case .owner: "owner"
            case .coOwner: "co-owner"
            case .blindOwner: "blind owner"
            case .memberRole: "MEMBER-role member"
            case .viewerRole: "VIEWER-role member"
            case .publicNonMember: "PUBLIC non-member"
            }
        }

        /// The persona's active-list spec (the flags the server sends before archiving).
        var activeSpec: ListFixtures.Spec {
            switch self {
            case .owner: ListFixtures.ownerOfChildList()
            case .coOwner: ListFixtures.blindCoOwner()
            case .blindOwner: ListFixtures.blindOwnerOfSelfList()
            case .memberRole: ListFixtures.memberRoleMember()
            case .viewerRole: ListFixtures.viewerRoleMember()
            case .publicNonMember: ListFixtures.publicNonMember()
            }
        }

        /// The same persona after the list was archived: status ARCHIVED, the four management
        /// flags false, every other flag unchanged (decision L16).
        var archivedSpec: ListFixtures.Spec {
            var spec = activeSpec
            spec.status = "ARCHIVED"
            spec.flags.canEditList = false
            spec.flags.canDeleteList = false
            spec.flags.canManageMembers = false
            spec.flags.canSetCoOwner = false
            return spec
        }
    }

    private func makeSUT(_ list: GiftList) -> ListRowState {
        ListRowState(list: list)
    }

    private func mapped(_ spec: ListFixtures.Spec) throws -> GiftList {
        mapListSummary(try ListFixtures.summary(spec))
    }

    // MARK: - Badge

    @Test("An archived list shows the Archived badge, for every persona", arguments: Persona.allCases)
    func archivedShowsBadge(persona: Persona) throws {
        let state = makeSUT(try mapped(persona.archivedSpec))
        #expect(state.isArchived)
        #expect(state.showsArchivedBadge)
    }

    @Test("An ACTIVE list shows no Archived badge, for every persona", arguments: Persona.allCases)
    func activeShowsNoBadge(persona: Persona) throws {
        let state = makeSUT(try mapped(persona.activeSpec))
        #expect(!state.isArchived)
        #expect(!state.showsArchivedBadge)
    }

    @Test("A DRAFT list is not archived and shows no badge")
    func draftShowsNoBadge() {
        let state = makeSUT(ListFixtures.giftList(status: .draft))
        #expect(!state.isArchived)
        #expect(!state.showsArchivedBadge)
    }

    @Test("The badge follows the status alone, not the flags")
    func badgeFollowsStatusNotFlags() {
        let allOn = ListFixtures.uniformFlags(true)
        let allOff = ListFixtures.uniformFlags(false)
        for flags in [allOn, allOff] {
            #expect(makeSUT(ListFixtures.giftList(status: .archived, flags: flags)).showsArchivedBadge)
            #expect(!makeSUT(ListFixtures.giftList(status: .active, flags: flags)).showsArchivedBadge)
        }
    }

    @Test("The badge text constant is Archived")
    func badgeTitleConstant() {
        #expect(ListArchivedBadge.title == "Archived")
    }

    // MARK: - Management actions come from the flags (false on archived)

    @Test("No persona is offered the delete (archive) action on an archived list", arguments: Persona.allCases)
    func archivedHasNoDeleteAction(persona: Persona) throws {
        #expect(!makeSUT(try mapped(persona.archivedSpec)).showsDeleteAction)
    }

    @Test("The delete action still follows canDeleteList on an active list",
          arguments: [(Persona.owner, true), (.coOwner, true), (.blindOwner, true),
                      (.memberRole, false), (.viewerRole, false), (.publicNonMember, false)])
    func activeDeleteFollowsFlag(persona: Persona, expected: Bool) throws {
        #expect(makeSUT(try mapped(persona.activeSpec)).showsDeleteAction == expected)
    }

    @Test("The delete action follows the flag even when the status is archived (flags decide, not status)")
    func deleteFollowsFlagNotStatus() {
        var on = ListFixtures.Flags()
        on.canDeleteList = true
        #expect(makeSUT(ListFixtures.giftList(status: .archived, flags: on)).showsDeleteAction)
        #expect(!makeSUT(ListFixtures.giftList(status: .archived, flags: ListFixtures.Flags())).showsDeleteAction)
    }

    // MARK: - Item and gift-activity flags are unaffected by status

    @Test("Counts and progress of an archived list follow canSeeGiftActivity exactly like an active one",
          arguments: Persona.allCases)
    func countsUnaffectedByStatus(persona: Persona) throws {
        let active = makeSUT(try mapped(persona.activeSpec))
        let archived = makeSUT(try mapped(persona.archivedSpec))
        #expect(archived.showsCounts == active.showsCounts)
        #expect(archived.itemCountText == active.itemCountText)
        #expect(archived.purchasedCountText == active.purchasedCountText)
        #expect(archived.showsProgress == active.showsProgress)
        #expect(archived.progress == active.progress)
    }

    @Test("Archived list as owner keeps its counts; as a blind persona it still hides them")
    func archivedCountsPerPersona() throws {
        let owner = makeSUT(try mapped(Persona.owner.archivedSpec))
        #expect(owner.showsCounts)
        #expect(owner.itemCountText != nil)
        for blind in [Persona.blindOwner, .coOwner, .viewerRole, .publicNonMember] {
            let state = makeSUT(try mapped(blind.archivedSpec))
            #expect(!state.showsCounts, "\(blind.testDescription) must not see counts")
            #expect(state.itemCountText == nil)
            #expect(state.purchasedCountText == nil)
            #expect(!state.showsProgress)
            #expect(state.progress == nil)
        }
    }

    @Test("The accessibility label of an archived list carries no ids and still names the list")
    func archivedAccessibilityLabel() throws {
        let spec = Persona.owner.archivedSpec
        let state = makeSUT(try mapped(spec))
        #expect(state.accessibilityLabel.contains("Fake Family List"))
        #expect(!state.accessibilityLabel.contains(spec.id))
    }
}
