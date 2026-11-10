//
//  MemberConfirmationTests.swift
//  ChristmasTrackerTests
//
//  Story I3b-M1: the remove-member and leave-list confirmation texts.
//

import Testing
import Foundation
@testable import ChristmasTracker

@Suite("Member confirmation Tests")
struct MemberConfirmationTests {

    // MARK: - Remove a member

    @Test("The remove title is not empty")
    func removeTitle() {
        #expect(!MemberRemoveConfirmation.title(displayName: "Casey Member").isEmpty)
    }

    @Test("The remove message names the person and says they lose access")
    func removeMessage() {
        let message = MemberRemoveConfirmation.message(displayName: "Casey Member")
        #expect(message.contains("Casey Member"))
        #expect(message.lowercased().contains("lose access"))
    }

    @Test("The remove texts follow the display name they are given")
    func removeFollowsName() {
        let first = MemberRemoveConfirmation.message(displayName: "Casey Member")
        let second = MemberRemoveConfirmation.message(displayName: "Sam Viewer")
        #expect(first != second)
        #expect(second.contains("Sam Viewer"))
        #expect(!second.contains("Casey Member"))
    }

    @Test("The remove texts never contain an email address")
    func removeHasNoEmail() {
        #expect(!MemberRemoveConfirmation.message(displayName: "Casey Member").contains("@"))
        #expect(!MemberRemoveConfirmation.title(displayName: "Casey Member").contains("@"))
    }

    @Test("The remove confirm button is named Remove")
    func removeButton() {
        #expect(MemberRemoveConfirmation.confirmButtonTitle.lowercased().contains("remove"))
    }

    // MARK: - Leave a list

    @Test("The leave title and button are not empty")
    func leaveTitleAndButton() {
        #expect(!LeaveListConfirmation.title.isEmpty)
        #expect(!LeaveListConfirmation.confirmButtonTitle.isEmpty)
        #expect(LeaveListConfirmation.confirmButtonTitle.lowercased().contains("leave"))
    }

    @Test("The leave message says the list will be removed from your lists")
    func leaveMessage() {
        #expect(LeaveListConfirmation.message.lowercased().contains("removed from your lists"))
    }

    @Test("The leave and delete confirmations are different")
    func leaveIsNotDelete() {
        #expect(LeaveListConfirmation.confirmButtonTitle != ListDeleteConfirmation.confirmButtonTitle)
        #expect(LeaveListConfirmation.title != ListDeleteConfirmation.title)
    }
}
