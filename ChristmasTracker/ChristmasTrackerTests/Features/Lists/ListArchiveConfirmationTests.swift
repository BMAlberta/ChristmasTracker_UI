//
//  ListArchiveConfirmationTests.swift
//  ChristmasTrackerTests
//
//  Story I3c-A: the Archive List confirmation texts. They replace ListDeleteConfirmation (and its
//  test file, ListDeleteConfirmationTests): deleting a list is presented as ARCHIVING it.
//

import Testing
import Foundation
@testable import ChristmasTracker

@Suite("List archive confirmation Tests")
struct ListArchiveConfirmationTests {

    @Test("The title asks whether to archive the list")
    func title() {
        #expect(ListArchiveConfirmation.title == "Archive this list?")
    }

    @Test("The message says the list moves to Archived, can no longer be edited, and items and purchases can still be recorded")
    func message() {
        #expect(ListArchiveConfirmation.message
            == "The list moves to Archived and can no longer be edited. Items and purchases can still be recorded there.")
    }

    @Test("The confirm button and the action are both Archive List")
    func buttonAndAction() {
        #expect(ListArchiveConfirmation.confirmButtonTitle == "Archive List")
        #expect(ListArchiveConfirmation.actionTitle == "Archive List")
    }

    @Test("The texts never say delete or removed")
    func noDeleteWording() {
        let texts = [
            ListArchiveConfirmation.title, ListArchiveConfirmation.message,
            ListArchiveConfirmation.confirmButtonTitle, ListArchiveConfirmation.actionTitle
        ]
        for text in texts {
            let lower = text.lowercased()
            #expect(!lower.contains("delete"), "'\(text)'")
            #expect(!lower.contains("removed"), "'\(text)'")
        }
    }

    @Test("The message names no list and has no format placeholder")
    func messageIsGeneric() {
        #expect(!ListArchiveConfirmation.message.contains("list-"))
        #expect(!ListArchiveConfirmation.message.contains("%@"))
    }

    @Test("The archive and leave confirmations are different")
    func differsFromLeave() {
        #expect(ListArchiveConfirmation.confirmButtonTitle != LeaveListConfirmation.confirmButtonTitle)
        #expect(ListArchiveConfirmation.title != LeaveListConfirmation.title)
    }
}
