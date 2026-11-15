//
//  EditListDialogTargetTests.swift
//  ChristmasTrackerTests
//
//  UX1b Story B1: EditListDialogTarget is a Hashable, Sendable value naming which edit-list dialog is
//  open.
//

import Testing
@testable import ChristmasTracker

@Suite("Edit list dialog target Tests")
struct EditListDialogTargetTests {

    @Test("OLD: the remove co-owner dialog was a loose Bool; the target value equals itself")
    func removeCoOwnerEquality() {
        #expect(EditListDialogTarget.removeCoOwner == EditListDialogTarget.removeCoOwner)
    }

    @Test("The target hashes to a single entry")
    func hashing() {
        let set: Set<EditListDialogTarget> = [.removeCoOwner, .removeCoOwner]
        #expect(set.count == 1)
    }

    @Test("A presentation over the target confirms and runs it")
    func worksWithConfirmationPresentation() {
        let sut = ConfirmationPresentation<EditListDialogTarget>.idle.requesting(.removeCoOwner)
        #expect(sut.isConfirming(.removeCoOwner))
        #expect(sut.confirmed(.removeCoOwner).run == .removeCoOwner)
    }
}
