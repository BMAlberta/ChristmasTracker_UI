//
//  ListDeleteConfirmationTests.swift
//  ChristmasTrackerTests
//
//  Story I3a-L3: the delete confirmation texts.
//

import Testing
import Foundation
@testable import ChristmasTracker

@Suite("List delete confirmation Tests")
struct ListDeleteConfirmationTests {

    @Test("Title and confirm button are non-empty")
    func titleAndButton() {
        #expect(!ListDeleteConfirmation.title.isEmpty)
        #expect(!ListDeleteConfirmation.confirmButtonTitle.isEmpty)
    }

    @Test("The message says the list will be removed from your lists")
    func messageText() {
        let message = ListDeleteConfirmation.message.lowercased()
        #expect(message.contains("removed"))
        #expect(message.contains("your lists"))
    }

    @Test("The message names no list and has no format placeholder")
    func messageIsGeneric() {
        #expect(!ListDeleteConfirmation.message.contains("list-"))
        #expect(!ListDeleteConfirmation.message.contains("%@"))
    }

    @Test("Title and message differ")
    func titleDiffersFromMessage() {
        #expect(ListDeleteConfirmation.title != ListDeleteConfirmation.message)
    }
}
