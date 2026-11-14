//
//  MembersDialogTargetTests.swift
//  ChristmasTrackerTests
//
//  UX1b Story B1: MembersDialogTarget is a Hashable, Sendable value naming which members dialog is
//  open. Fake ids only.
//

import Testing
@testable import ChristmasTracker

@Suite("Members dialog target Tests")
struct MembersDialogTargetTests {

    @Test("OLD: leave and remove were two loose flags; leave equals leave")
    func leaveEqualsLeave() {
        #expect(MembersDialogTarget.leave == MembersDialogTarget.leave)
    }

    @Test("Remove targets are equal only for the same user id")
    func removeEquality() {
        #expect(MembersDialogTarget.removeMember(userId: "user-1") == .removeMember(userId: "user-1"))
        #expect(MembersDialogTarget.removeMember(userId: "user-1") != .removeMember(userId: "user-2"))
    }

    @Test("Leave and remove are different targets")
    func leaveDiffersFromRemove() {
        #expect(MembersDialogTarget.leave != .removeMember(userId: "user-1"))
    }

    @Test("Hashing keeps one entry per distinct target")
    func hashing() {
        let set: Set<MembersDialogTarget> = [
            .leave, .leave, .removeMember(userId: "user-1"), .removeMember(userId: "user-1"), .removeMember(userId: "user-2")
        ]
        #expect(set.count == 3)
        #expect(set.contains(.removeMember(userId: "user-2")))
    }
}
