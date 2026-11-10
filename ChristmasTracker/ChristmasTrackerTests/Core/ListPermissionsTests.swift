//
//  ListPermissionsTests.swift
//  ChristmasTrackerTests
//
//  Story I3a-L1: ListPermissions is the ONE flag-driven source of every list-level decision.
//
//  Part A: exhaustive truth table (all 2^12 flag combinations) against an independently
//          written oracle.
//  Part B: named privacy scenarios.
//  Part C: ListCategory.
//
//  Fails today because ListCapabilities, ListPermissions and ListCategory do not exist yet.
//

import Testing
import Foundation
@testable import ChristmasTracker

@Suite("ListPermissions Tests")
struct ListPermissionsTests {

    // MARK: - Factory

    private func makeSUT(_ flags: ListFixtures.Flags) -> ListPermissions {
        ListPermissions(ListFixtures.capabilities(flags))
    }

    // MARK: - Oracle (written independently of the production code)

    private struct Expected {
        let canEditList: Bool
        let canDeleteList: Bool
        let canManageMembers: Bool
        let canSetCoOwner: Bool
        let canLeaveList: Bool
        let showsMembersSection: Bool
        let category: ListCategory

        init(_ f: ListFixtures.Flags) {
            canEditList = f.canEditList
            canDeleteList = f.canDeleteList
            canManageMembers = f.canManageMembers
            canSetCoOwner = f.canSetCoOwner
            canLeaveList = f.canLeaveList
            showsMembersSection = f.canSeeMembers
            category = (f.canEditList || f.canDeleteList || f.canManageMembers) ? .owned : .shared
        }

        func showsCounts(_ f: ListFixtures.Flags, _ items: Int?, _ purchased: Int?) -> Bool {
            guard f.canSeeGiftActivity else { return false }
            guard let _ = items, let _ = purchased else { return false }
            return true
        }

        func showsProgress(_ f: ListFixtures.Flags, _ items: Int?, _ purchased: Int?) -> Bool {
            guard showsCounts(f, items, purchased), let items else { return false }
            return items > 0
        }
    }

    private static let countCombos: [(Int?, Int?)] = [
        (nil, nil), (5, nil), (nil, 2), (5, 2), (0, 0), (0, nil), (1, 1)
    ]

    // MARK: - Part A: truth table

    @Test("Truth table: all 4096 flag combinations match the oracle")
    func truthTableAllCombinations() {
        var mismatches: [String] = []
        for bits in 0..<4096 {
            let flags = ListFixtures.flags(bits: bits)
            let sut = makeSUT(flags)
            let oracle = Expected(flags)

            if sut.canEditList != oracle.canEditList { mismatches.append("\(bits): canEditList") }
            if sut.canDeleteList != oracle.canDeleteList { mismatches.append("\(bits): canDeleteList") }
            if sut.canManageMembers != oracle.canManageMembers { mismatches.append("\(bits): canManageMembers") }
            if sut.canSetCoOwner != oracle.canSetCoOwner { mismatches.append("\(bits): canSetCoOwner") }
            if sut.canLeaveList != oracle.canLeaveList { mismatches.append("\(bits): canLeaveList") }
            if sut.showsMembersSection != oracle.showsMembersSection { mismatches.append("\(bits): showsMembersSection") }
            if sut.category != oracle.category { mismatches.append("\(bits): category") }

            for (items, purchased) in Self.countCombos {
                let counts = sut.showsCounts(itemCount: items, purchasedCount: purchased)
                if counts != oracle.showsCounts(flags, items, purchased) {
                    mismatches.append("\(bits): showsCounts(\(String(describing: items)), \(String(describing: purchased)))")
                }
                let progress = sut.showsProgress(itemCount: items, purchasedCount: purchased)
                if progress != oracle.showsProgress(flags, items, purchased) {
                    mismatches.append("\(bits): showsProgress(\(String(describing: items)), \(String(describing: purchased)))")
                }
            }
        }
        #expect(mismatches.isEmpty, "First mismatches: \(mismatches.prefix(10))")
    }

    @Test("Truth table covers 4096 distinct combinations of exactly twelve flags")
    func truthTableEnumeratesEveryCombination() {
        var seen = Set<Int>()
        for bits in 0..<4096 {
            let f = ListFixtures.flags(bits: bits)
            let key = [f.isRecipient, f.canSeeGiftActivity, f.canPurchase, f.canAddOffList,
                       f.canSeeOffList, f.canCreateItem, f.canSeeMembers, f.canEditList,
                       f.canDeleteList, f.canManageMembers, f.canSetCoOwner, f.canLeaveList]
                .enumerated().reduce(0) { $0 | ($1.element ? 1 << $1.offset : 0) }
            seen.insert(key)
        }
        #expect(seen.count == 4096)
    }

    @Test("Each result mirrors exactly one flag: flipping only that flag flips only that result")
    func eachResultMirrorsExactlyOneFlag() {
        let none = makeSUT(ListFixtures.uniformFlags(false))
        #expect(none.canEditList == false)
        #expect(none.canDeleteList == false)
        #expect(none.canManageMembers == false)
        #expect(none.canSetCoOwner == false)
        #expect(none.canLeaveList == false)
        #expect(none.showsMembersSection == false)
        #expect(none.category == .shared)

        var f = ListFixtures.Flags(); f.canEditList = true
        var sut = makeSUT(f)
        #expect(sut.canEditList == true && sut.canDeleteList == false && sut.canManageMembers == false)
        #expect(sut.canSetCoOwner == false && sut.canLeaveList == false && sut.showsMembersSection == false)

        f = ListFixtures.Flags(); f.canDeleteList = true
        sut = makeSUT(f)
        #expect(sut.canDeleteList == true && sut.canEditList == false && sut.canManageMembers == false)
        #expect(sut.canSetCoOwner == false && sut.canLeaveList == false && sut.showsMembersSection == false)

        f = ListFixtures.Flags(); f.canManageMembers = true
        sut = makeSUT(f)
        #expect(sut.canManageMembers == true && sut.canEditList == false && sut.canDeleteList == false)
        #expect(sut.canSetCoOwner == false && sut.canLeaveList == false && sut.showsMembersSection == false)

        f = ListFixtures.Flags(); f.canSetCoOwner = true
        sut = makeSUT(f)
        #expect(sut.canSetCoOwner == true && sut.canEditList == false && sut.canDeleteList == false)
        #expect(sut.canManageMembers == false && sut.canLeaveList == false && sut.showsMembersSection == false)
        #expect(sut.category == .shared, "canSetCoOwner alone does not make a list owned")

        f = ListFixtures.Flags(); f.canLeaveList = true
        sut = makeSUT(f)
        #expect(sut.canLeaveList == true && sut.canSetCoOwner == false && sut.showsMembersSection == false)
        #expect(sut.category == .shared)

        f = ListFixtures.Flags(); f.canSeeMembers = true
        sut = makeSUT(f)
        #expect(sut.showsMembersSection == true && sut.canLeaveList == false && sut.canEditList == false)
        #expect(sut.category == .shared, "canSeeMembers alone does not make a list owned")
    }

    // MARK: - Counts and progress boundaries

    @Test("showsCounts needs canSeeGiftActivity and both counts")
    func showsCountsRequiresFlagAndBothCounts() {
        var flags = ListFixtures.Flags()
        flags.canSeeGiftActivity = true
        let sut = makeSUT(flags)
        #expect(sut.showsCounts(itemCount: 4, purchasedCount: 1) == true)
        #expect(sut.showsCounts(itemCount: nil, purchasedCount: 1) == false)
        #expect(sut.showsCounts(itemCount: 4, purchasedCount: nil) == false)
        #expect(sut.showsCounts(itemCount: nil, purchasedCount: nil) == false)
        #expect(sut.showsCounts(itemCount: 0, purchasedCount: 0) == true)
    }

    @Test("showsProgress is false when itemCount is 0 even with the flag and counts")
    func showsProgressFalseForZeroItems() {
        var flags = ListFixtures.Flags()
        flags.canSeeGiftActivity = true
        let sut = makeSUT(flags)
        #expect(sut.showsProgress(itemCount: 0, purchasedCount: 0) == false)
        #expect(sut.showsProgress(itemCount: 1, purchasedCount: 0) == true)
        #expect(sut.showsProgress(itemCount: 3, purchasedCount: 3) == true)
    }

    @Test("Without canSeeGiftActivity counts and progress never show, even when counts are passed")
    func countsHiddenWithoutGiftActivity() {
        let sut = makeSUT(ListFixtures.Flags())
        #expect(sut.showsCounts(itemCount: 9, purchasedCount: 4) == false)
        #expect(sut.showsProgress(itemCount: 9, purchasedCount: 4) == false)
    }

    // MARK: - Part B: named scenarios

    @Test("Blind owner shows no counts and no progress even when counts are passed")
    func blindOwnerShowsNoCountsEvenIfPassed() {
        let sut = makeSUT(ListFixtures.blindOwnerOfSelfList().flags)
        #expect(sut.showsCounts(itemCount: 6, purchasedCount: 2) == false)
        #expect(sut.showsProgress(itemCount: 6, purchasedCount: 2) == false)
        #expect(sut.canEditList == true)
        #expect(sut.canDeleteList == true)
        #expect(sut.canSetCoOwner == true)
        #expect(sut.category == .owned)
    }

    @Test("Owner of a child list shows counts and progress when counts are present")
    func childOwnerShowsCounts() {
        let sut = makeSUT(ListFixtures.ownerOfChildList().flags)
        #expect(sut.showsCounts(itemCount: 8, purchasedCount: 3) == true)
        #expect(sut.showsProgress(itemCount: 8, purchasedCount: 3) == true)
        #expect(sut.showsCounts(itemCount: nil, purchasedCount: nil) == false)
        #expect(sut.category == .owned)
    }

    @Test("MEMBER-role member: members section and leave, no management, shared")
    func memberScenario() {
        let sut = makeSUT(ListFixtures.memberRoleMember().flags)
        #expect(sut.showsMembersSection == true)
        #expect(sut.canLeaveList == true)
        #expect(sut.canEditList == false)
        #expect(sut.canDeleteList == false)
        #expect(sut.canManageMembers == false)
        #expect(sut.canSetCoOwner == false)
        #expect(sut.category == .shared)
        #expect(sut.showsCounts(itemCount: 5, purchasedCount: 2) == true)
    }

    @Test("VIEWER-role member: no members section, no counts, may leave, shared")
    func viewerScenario() {
        let sut = makeSUT(ListFixtures.viewerRoleMember().flags)
        #expect(sut.showsMembersSection == false)
        #expect(sut.canLeaveList == true)
        #expect(sut.showsCounts(itemCount: 5, purchasedCount: 2) == false)
        #expect(sut.category == .shared)
    }

    @Test("PUBLIC non-member: cannot leave, no members, no counts, shared")
    func publicNonMemberScenario() {
        let sut = makeSUT(ListFixtures.publicNonMember().flags)
        #expect(sut.canLeaveList == false)
        #expect(sut.showsMembersSection == false)
        #expect(sut.showsCounts(itemCount: 5, purchasedCount: 2) == false)
        #expect(sut.category == .shared)
    }

    @Test("Blind co-owner: edit and delete but not set co-owner, owned, no counts")
    func blindCoOwnerScenario() {
        let sut = makeSUT(ListFixtures.blindCoOwner().flags)
        #expect(sut.canEditList == true)
        #expect(sut.canDeleteList == true)
        #expect(sut.canManageMembers == true)
        #expect(sut.canSetCoOwner == false)
        #expect(sut.category == .owned)
        #expect(sut.showsCounts(itemCount: 3, purchasedCount: 1) == false)
    }

    @Test("An ARCHIVED list is never editable, deletable or manageable, whoever the viewer is")
    func archivedListNeverEditable() {
        let owner = makeSUT(ListFixtures.archivedAsOwner().flags)
        #expect(owner.canEditList == false)
        #expect(owner.canDeleteList == false)
        #expect(owner.canManageMembers == false)
        #expect(owner.canSetCoOwner == false)

        let member = makeSUT(ListFixtures.archivedAsMember().flags)
        #expect(member.canEditList == false)
        #expect(member.canDeleteList == false)
        #expect(member.canManageMembers == false)
        #expect(member.canLeaveList == true, "A member may leave a list of any status")
    }

    @Test("Permissions follow the flags and never the role: a viewer role with edit flags may edit")
    func permissionsIgnoreRole() {
        // A GiftList whose myRole says viewer but whose flags grant edit.
        let list = ListFixtures.giftList(
            myRole: .viewer,
            flags: ListFixtures.Flags(canEditList: true, canDeleteList: true)
        )
        let sut = ListPermissions(list.capabilities)
        #expect(sut.canEditList == true)
        #expect(sut.canDeleteList == true)
        #expect(sut.category == .owned)

        // And an owner role whose flags grant nothing may do nothing.
        let ownerRoleNoFlags = ListFixtures.giftList(myRole: .owner, flags: ListFixtures.Flags())
        let none = ListPermissions(ownerRoleNoFlags.capabilities)
        #expect(none.canEditList == false)
        #expect(none.category == .shared)
    }

    // MARK: - Part C: ListCategory

    @Test("Category is owned when any one of canEditList, canDeleteList, canManageMembers is true")
    func categoryOwnedWhenAnyManagementFlag() {
        var f = ListFixtures.Flags(); f.canEditList = true
        #expect(makeSUT(f).category == .owned)
        f = ListFixtures.Flags(); f.canDeleteList = true
        #expect(makeSUT(f).category == .owned)
        f = ListFixtures.Flags(); f.canManageMembers = true
        #expect(makeSUT(f).category == .owned)
    }

    @Test("Category is shared when none of the three management flags is true, whatever the others are")
    func categorySharedWithoutManagementFlags() {
        var f = ListFixtures.uniformFlags(true)
        f.canEditList = false
        f.canDeleteList = false
        f.canManageMembers = false
        #expect(makeSUT(f).category == .shared)
        #expect(makeSUT(ListFixtures.uniformFlags(false)).category == .shared)
    }

    @Test("ListCategory has exactly the two cases owned and shared")
    func categoryHasTwoCases() {
        let cases: [ListCategory] = [.owned, .shared]
        #expect(cases.count == 2)
        #expect(ListCategory.owned != ListCategory.shared)
    }
}
