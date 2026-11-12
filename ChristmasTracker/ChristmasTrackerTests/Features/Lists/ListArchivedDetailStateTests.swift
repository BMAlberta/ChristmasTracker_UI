//
//  ListArchivedDetailStateTests.swift
//  ChristmasTrackerTests
//
//  Story I3c-A: ListDetailState for ARCHIVED lists, per persona, driven by flags only. An
//  archived list opens like any other: the four management flags are false (so no edit, delete
//  or member management), and the item and gift-activity flags decide the rest, unaffected by
//  status (decision L16). Fake data only.
//

import Testing
import Foundation
@testable import ChristmasTracker

@Suite("List archived detail state Tests")
struct ListArchivedDetailStateTests {

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

        var archivedSpec: ListFixtures.Spec {
            var spec = activeSpec
            spec.status = "ARCHIVED"
            spec.flags.canEditList = false
            spec.flags.canDeleteList = false
            spec.flags.canManageMembers = false
            spec.flags.canSetCoOwner = false
            return spec
        }

        /// The item flag the persona has, straight from the privacy matrix (docs/privacy-matrix.md):
        /// every persona except the VIEWER-role member and the PUBLIC non-member may add an item.
        var canCreateItem: Bool {
            switch self {
            case .owner, .coOwner, .blindOwner, .memberRole: true
            case .viewerRole, .publicNonMember: false
            }
        }
    }

    private func makeSUT(_ detail: ListDetail) -> ListDetailState {
        ListDetailState(detail: detail)
    }

    private func mapped(_ spec: ListFixtures.Spec) throws -> ListDetail {
        mapListDetail(try ListFixtures.detail(spec))
    }

    // MARK: - Badge

    @Test("An archived detail shows the Archived badge, for every persona", arguments: Persona.allCases)
    func archivedShowsBadge(persona: Persona) throws {
        let state = makeSUT(try mapped(persona.archivedSpec))
        #expect(state.isArchived)
        #expect(state.showsArchivedBadge)
    }

    @Test("An active or draft detail shows no Archived badge", arguments: [ListStatus.active, .draft])
    func nonArchivedShowsNoBadge(status: ListStatus) {
        let state = makeSUT(ListFixtures.listDetail(status: status))
        #expect(!state.isArchived)
        #expect(!state.showsArchivedBadge)
    }

    @Test("The badge follows the status alone, not the flags")
    func badgeFollowsStatusNotFlags() {
        for flags in [ListFixtures.uniformFlags(true), ListFixtures.uniformFlags(false)] {
            #expect(makeSUT(ListFixtures.listDetail(status: .archived, flags: flags)).showsArchivedBadge)
            #expect(!makeSUT(ListFixtures.listDetail(status: .active, flags: flags)).showsArchivedBadge)
        }
    }

    // MARK: - Management controls are absent because their flags are false

    @Test("No persona sees edit or delete on an archived detail", arguments: Persona.allCases)
    func archivedHasNoManagement(persona: Persona) throws {
        let state = makeSUT(try mapped(persona.archivedSpec))
        #expect(!state.showsEditAction)
        #expect(!state.showsDeleteAction)
    }

    @Test("Edit and delete follow their flags even when the status is archived (flags decide, not status)")
    func managementFollowsFlagsNotStatus() {
        var flags = ListFixtures.Flags()
        flags.canEditList = true
        flags.canDeleteList = true
        let state = makeSUT(ListFixtures.listDetail(status: .archived, flags: flags))
        #expect(state.showsEditAction)
        #expect(state.showsDeleteAction)
    }

    // MARK: - Items follow canCreateItem, not status

    @Test("showsAddItemAction on an archived detail follows canCreateItem per persona", arguments: Persona.allCases)
    func addItemFollowsFlagOnArchived(persona: Persona) throws {
        let state = makeSUT(try mapped(persona.archivedSpec))
        #expect(state.showsAddItemAction == persona.canCreateItem)
    }

    @Test("showsAddItemAction is the same on an archived and an active detail, for every persona",
          arguments: Persona.allCases)
    func addItemUnaffectedByStatus(persona: Persona) throws {
        let active = makeSUT(try mapped(persona.activeSpec))
        let archived = makeSUT(try mapped(persona.archivedSpec))
        #expect(archived.showsAddItemAction == active.showsAddItemAction)
    }

    @Test("showsAddItemAction follows canCreateItem alone on an archived detail")
    func addItemFollowsFlagAlone() {
        var on = ListFixtures.Flags()
        on.canCreateItem = true
        #expect(makeSUT(ListFixtures.listDetail(status: .archived, flags: on)).showsAddItemAction)
        #expect(!makeSUT(ListFixtures.listDetail(status: .archived, flags: ListFixtures.Flags())).showsAddItemAction)
        let everythingButCreate = ListFixtures.uniformFlags(true).withoutCreateItem()
        #expect(!makeSUT(ListFixtures.listDetail(status: .archived, flags: everythingButCreate)).showsAddItemAction)
    }

    // MARK: - Gift activity and members follow their flags, not status

    @Test("Stats and progress of an archived detail match the active one, for every persona", arguments: Persona.allCases)
    func statsUnaffectedByStatus(persona: Persona) throws {
        let active = makeSUT(try mapped(persona.activeSpec))
        let archived = makeSUT(try mapped(persona.archivedSpec))
        #expect(archived.showsStatsCard == active.showsStatsCard)
        #expect(archived.itemCountText == active.itemCountText)
        #expect(archived.purchasedCountText == active.purchasedCountText)
        #expect(archived.showsProgress == active.showsProgress)
        #expect(archived.progress == active.progress)
        #expect(archived.showsMembersSection == active.showsMembersSection)
    }

    @Test("Blind personas see no stats on an archived detail and nothing hints at hidden state")
    func blindPersonasHideStats() throws {
        for persona in [Persona.blindOwner, .coOwner, .viewerRole, .publicNonMember] {
            let state = makeSUT(try mapped(persona.archivedSpec))
            #expect(!state.showsStatsCard, "\(persona.testDescription)")
            #expect(state.itemCountText == nil)
            #expect(state.purchasedCountText == nil)
            #expect(!state.showsProgress)
            #expect(state.progress == nil)
        }
    }

    @Test("The archived owner and MEMBER-role member keep their stats")
    func sightedPersonasKeepStats() throws {
        for persona in [Persona.owner, .memberRole] {
            let state = makeSUT(try mapped(persona.archivedSpec))
            #expect(state.showsStatsCard, "\(persona.testDescription)")
            #expect(state.itemCountText != nil)
            #expect(state.purchasedCountText != nil)
        }
    }
}

private extension ListFixtures.Flags {
    func withoutCreateItem() -> ListFixtures.Flags {
        var copy = self
        copy.canCreateItem = false
        return copy
    }
}
