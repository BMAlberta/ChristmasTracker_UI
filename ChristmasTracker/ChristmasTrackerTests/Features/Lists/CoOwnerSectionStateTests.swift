//
//  CoOwnerSectionStateTests.swift
//  ChristmasTrackerTests
//
//  Story I3b-M1: CoOwnerSectionState. "Change co-owner" follows canSetCoOwner. "Remove
//  co-owner" is hidden for now because the generated update payload cannot send an explicit
//  null (see the I3b Decisions), so `clearingSupported` is false and showsRemove is false for
//  every flag combination. The formula is pinned so flipping the constant later is the only
//  change needed.
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

    // MARK: - Clearing

    @Test("Clearing is not supported by the generated client today")
    func clearingNotSupported() {
        #expect(CoOwnerSectionState.clearingSupported == false)
    }

    @Test("showsRemove is false for every flag combination, with and without a co-owner")
    func removeNeverShowsToday() throws {
        for bits in 0..<16 {
            for hasCoOwner in [true, false] {
                let flags = MembersFixtures.sectionFlags(bits: bits)
                let detail = try MembersFixtures.detail(flags: flags, hasCoOwner: hasCoOwner)
                #expect(CoOwnerSectionState(detail: detail).showsRemove == false, "bits \(bits) coOwner \(hasCoOwner)")
            }
        }
    }

    @Test("The showsRemove formula is canSetCoOwner && coOwner != nil && clearingSupported")
    func removeFormula() throws {
        for canSet in [true, false] {
            for hasCoOwner in [true, false] {
                let state = try makeSUT(canSetCoOwner: canSet, hasCoOwner: hasCoOwner)
                let expected = canSet && hasCoOwner && CoOwnerSectionState.clearingSupported
                #expect(state.showsRemove == expected, "canSet \(canSet) coOwner \(hasCoOwner)")
            }
        }
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
    }
}
