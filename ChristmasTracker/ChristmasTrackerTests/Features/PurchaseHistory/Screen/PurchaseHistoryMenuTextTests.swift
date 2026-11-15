//
//  PurchaseHistoryMenuTextTests.swift
//  ChristmasTrackerTests
//
//  PH1-H3: the menu button titles and the accessibility labels and values of the three filter menus.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("Purchase history menu text")
struct PurchaseHistoryMenuTextTests {

    private typealias Screen = PurchaseHistoryScreenState

    private let people = [
        PurchaseHistoryRecipient(id: "p1", name: "Alex Rivera"),
        PurchaseHistoryRecipient(id: "p2", name: "Sam Okafor")
    ]

    @Test("The year title shows the year or All years")
    func yearTitle() {
        #expect(Screen.yearTitle(2026) == "2026")
        #expect(Screen.yearTitle(nil) == "All years")
    }

    @Test("The shipping title shows the status name or All shipping")
    func shippingTitle() {
        #expect(Screen.shippingTitle(.notShipped) == "Not shipped")
        #expect(Screen.shippingTitle(nil) == "All shipping")
    }

    @Test("The recipient title shows the person's name or All people")
    func recipientTitle() {
        #expect(Screen.recipientTitle(recipientId: "p2", people: people) == "Sam Okafor")
        #expect(Screen.recipientTitle(recipientId: nil, people: people) == "All people")
    }

    @Test("An id that is not in the list reads as a person, never as the id")
    func recipientUnknown() {
        #expect(Screen.recipientTitle(recipientId: "ghost", people: people) == "Person")
    }

    @Test("The accessibility labels name the menu")
    func labels() {
        #expect(Screen.yearAccessibilityLabel == "Year")
        #expect(Screen.shippingAccessibilityLabel == "Shipping")
        #expect(Screen.recipientAccessibilityLabel == "Recipient")
    }

    @Test("The accessibility values are the current selection in words")
    func values() {
        #expect(Screen.yearAccessibilityValue(2025) == "2025")
        #expect(Screen.yearAccessibilityValue(nil) == "All years")
        #expect(Screen.shippingAccessibilityValue(.delivered) == "Delivered")
        #expect(Screen.shippingAccessibilityValue(nil) == "All")
        #expect(Screen.recipientAccessibilityValue(recipientId: "p1", people: people) == "Alex Rivera")
        #expect(Screen.recipientAccessibilityValue(recipientId: nil, people: people) == "All people")
    }
}
