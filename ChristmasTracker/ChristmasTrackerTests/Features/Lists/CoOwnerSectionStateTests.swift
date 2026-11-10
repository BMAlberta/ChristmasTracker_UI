//
//  CoOwnerSectionStateTests.swift
//  ChristmasTrackerTests
//
//  Story I3b-2 R3: CoOwnerSectionState after the removeCoOwner operation exists.
//  showsChange = canSetCoOwner; showsRemove = canSetCoOwner && a co-owner is present. No role is
//  read. `clearingSupported` is gone, so the tests that pinned it are rewritten or deleted:
//   - DELETED  `clearingNotSupported` (asserted the removed constant).
//   - REWRITTEN `removeNeverShowsToday` -> `removeFollowsFlagAndCoOwner` (it asserted
//     showsRemove == false for every input, the old "clearing is blocked" behavior).
//   - REWRITTEN `removeFormula` (the formula no longer has the clearingSupported term).
//
//  The persona table uses the flag sets of Docs/client-guide.md (6.1 list management table) and
//  Docs/privacy-matrix.md (DELETE /lists/{id}/co-owner: 200 for the owner of a self or child
//  list; 403 for the co-owner, MEMBER and VIEWER members and PUBLIC non-members).
//

import Testing
import Foundation
@testable import ChristmasTracker

@Suite("CoOwnerSectionState Tests")
struct CoOwnerSectionStateTests {

    // MARK: - Factory

    private func makeSUT(canSetCoOwner: Bool, hasCoOwner: Bool, bits: Int = 0) throws -> CoOwnerSectionState {
        var flags = MembersFixtures.sectionFlags(bits: bits)
        flags.canSetCoOwner = canSetCoOwner
        let detail = try MembersFixtures.detail(flags: flags, hasCoOwner: hasCoOwner)
        return CoOwnerSectionState(detail: detail)
    }

    // MARK: - Remove

    @Test("showsRemove is canSetCoOwner && a co-owner is present, for every flag combination")
    func removeFollowsFlagAndCoOwner() throws {
        for bits in 0..<16 {
            for hasCoOwner in [true, false] {
                let flags = MembersFixtures.sectionFlags(bits: bits)
                let detail = try MembersFixtures.detail(flags: flags, hasCoOwner: hasCoOwner)
                let expected = flags.canSetCoOwner && hasCoOwner
                #expect(CoOwnerSectionState(detail: detail).showsRemove == expected, "bits \(bits) coOwner \(hasCoOwner)")
            }
        }
    }

    @Test("The showsRemove formula is canSetCoOwner && coOwner != nil")
    func removeFormula() throws {
        for canSet in [true, false] {
            for hasCoOwner in [true, false] {
                let state = try makeSUT(canSetCoOwner: canSet, hasCoOwner: hasCoOwner)
                #expect(state.showsRemove == (canSet && hasCoOwner), "canSet \(canSet) coOwner \(hasCoOwner)")
            }
        }
    }

    @Test("Remove shows for the owner when a co-owner exists, and only then")
    func removeShowsForOwnerWithCoOwner() throws {
        #expect(try makeSUT(canSetCoOwner: true, hasCoOwner: true).showsRemove)
        #expect(try !makeSUT(canSetCoOwner: true, hasCoOwner: false).showsRemove)
        #expect(try !makeSUT(canSetCoOwner: false, hasCoOwner: true).showsRemove)
    }

    @Test("No other flag turns Remove on", arguments: Array(0..<16))
    func otherFlagsDoNotTurnRemoveOn(bits: Int) throws {
        let flags = MembersFixtures.sectionFlags(bits: bits)
        let detail = try MembersFixtures.detail(flags: flags, hasCoOwner: true)
        #expect(CoOwnerSectionState(detail: detail).showsRemove == flags.canSetCoOwner)
    }

    @Test("myRole never changes the outcome, only the flag does", arguments: ["owner", "co-owner", "member", "viewer"])
    func roleIsNotRead(myRole: String) throws {
        var flags = MembersFixtures.sectionFlags(bits: 0)
        flags.canSetCoOwner = true
        let allowed = try MembersFixtures.detail(flags: flags, hasCoOwner: true, myRole: myRole)
        #expect(CoOwnerSectionState(detail: allowed).showsRemove)
        #expect(CoOwnerSectionState(detail: allowed).showsChange)
        flags.canSetCoOwner = false
        let denied = try MembersFixtures.detail(flags: flags, hasCoOwner: true, myRole: myRole)
        #expect(!CoOwnerSectionState(detail: denied).showsRemove)
        #expect(!CoOwnerSectionState(detail: denied).showsChange)
    }

    // MARK: - Personas (guide flag sets)

    nonisolated struct Persona: Sendable, CustomTestStringConvertible {
        let name: String
        /// (canSeeMembers, canManageMembers, canSetCoOwner, canLeaveList) as the guide lists them.
        let flags: MembersFixtures.SectionFlags
        let hasCoOwner: Bool
        let status: String
        let visibility: String
        let myRole: String
        let showsChange: Bool
        let showsRemove: Bool

        var testDescription: String { name }
    }

    nonisolated private static func flags(_ see: Bool, _ manage: Bool, _ setCoOwner: Bool, _ leave: Bool) -> MembersFixtures.SectionFlags {
        MembersFixtures.SectionFlags(
            canSeeMembers: see, canManageMembers: manage, canLeaveList: leave, canSetCoOwner: setCoOwner
        )
    }

    nonisolated static let personas: [Persona] = [
        Persona(name: "owner with a co-owner", flags: flags(true, true, true, false), hasCoOwner: true,
                status: "ACTIVE", visibility: "PRIVATE", myRole: "owner", showsChange: true, showsRemove: true),
        Persona(name: "owner without a co-owner", flags: flags(true, true, true, false), hasCoOwner: false,
                status: "ACTIVE", visibility: "PRIVATE", myRole: "owner", showsChange: true, showsRemove: false),
        Persona(name: "co-owner", flags: flags(true, true, false, false), hasCoOwner: true,
                status: "ACTIVE", visibility: "PRIVATE", myRole: "co-owner", showsChange: false, showsRemove: false),
        Persona(name: "blind co-owner", flags: flags(true, true, false, false), hasCoOwner: true,
                status: "ACTIVE", visibility: "PRIVATE", myRole: "co-owner", showsChange: false, showsRemove: false),
        Persona(name: "MEMBER-role member", flags: flags(true, false, false, true), hasCoOwner: true,
                status: "ACTIVE", visibility: "PRIVATE", myRole: "member", showsChange: false, showsRemove: false),
        Persona(name: "VIEWER-role member", flags: flags(false, false, false, true), hasCoOwner: true,
                status: "ACTIVE", visibility: "PRIVATE", myRole: "viewer", showsChange: false, showsRemove: false),
        Persona(name: "PUBLIC non-member", flags: flags(false, false, false, false), hasCoOwner: true,
                status: "ACTIVE", visibility: "PUBLIC", myRole: "viewer", showsChange: false, showsRemove: false),
        Persona(name: "archived list (all management flags false)", flags: flags(true, false, false, true),
                hasCoOwner: true, status: "ARCHIVED", visibility: "PRIVATE", myRole: "owner",
                showsChange: false, showsRemove: false)
    ]

    @Test("Each persona sees exactly what its flags allow", arguments: CoOwnerSectionStateTests.personas)
    func personaOutcome(persona: Persona) throws {
        let detail = try MembersFixtures.detail(
            flags: persona.flags, hasCoOwner: persona.hasCoOwner,
            status: persona.status, visibility: persona.visibility, myRole: persona.myRole
        )
        let state = CoOwnerSectionState(detail: detail)
        #expect(state.showsChange == persona.showsChange)
        #expect(state.showsRemove == persona.showsRemove)
    }

    // MARK: - Change

    @Test("showsChange follows canSetCoOwner, with or without a current co-owner")
    func changeFollowsFlag() throws {
        #expect(try makeSUT(canSetCoOwner: true, hasCoOwner: true).showsChange)
        #expect(try makeSUT(canSetCoOwner: true, hasCoOwner: false).showsChange)
        #expect(try !makeSUT(canSetCoOwner: false, hasCoOwner: true).showsChange)
        #expect(try !makeSUT(canSetCoOwner: false, hasCoOwner: false).showsChange)
    }

    @Test("No other flag turns Change on", arguments: Array(0..<16))
    func otherFlagsDoNotMatter(bits: Int) throws {
        let flags = MembersFixtures.sectionFlags(bits: bits)
        let detail = try MembersFixtures.detail(flags: flags)
        #expect(CoOwnerSectionState(detail: detail).showsChange == flags.canSetCoOwner)
    }

    // MARK: - Current co-owner

    @Test("The current co-owner shows by display name only")
    func currentName() throws {
        let state = try makeSUT(canSetCoOwner: true, hasCoOwner: true)
        #expect(state.currentCoOwnerName == MembersFixtures.coOwnerName)
        #expect(state.currentCoOwnerName?.contains("@") == false)
        #expect(state.currentCoOwnerName?.contains(MembersFixtures.coOwnerEmail) == false)
    }

    @Test("No co-owner means no name")
    func noName() throws {
        #expect(try makeSUT(canSetCoOwner: true, hasCoOwner: false).currentCoOwnerName == nil)
    }

    @Test("The name is shown to a viewer who may not change it")
    func nameShownWithoutChange() throws {
        let state = try makeSUT(canSetCoOwner: false, hasCoOwner: true)
        #expect(state.currentCoOwnerName == MembersFixtures.coOwnerName)
        #expect(!state.showsChange)
        #expect(!state.showsRemove)
    }
}
