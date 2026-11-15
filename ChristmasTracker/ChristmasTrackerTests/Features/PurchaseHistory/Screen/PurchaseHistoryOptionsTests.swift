//
//  PurchaseHistoryOptionsTests.swift
//  ChristmasTrackerTests
//
//  PH1-H3: the option lists of the three filter menus (pure).
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("Purchase history filter options")
struct PurchaseHistoryOptionsTests {

    private typealias Screen = PurchaseHistoryScreenState

    // MARK: Year

    @Test("Year options start with All years (nil), then the choices in the given order")
    func yearOrder() {
        let options = Screen.yearOptions(choices: [2026, 2025, 2024], selected: 2026)

        #expect(options.map(\.title) == ["All years", "2026", "2025", "2024"])
        #expect(options.map(\.value) == [nil, 2026, 2025, 2024])
    }

    @Test("The current filter year is included even when the choices do not have it")
    func yearIncludesSelected() {
        let options = Screen.yearOptions(choices: [2026, 2025], selected: 2019)

        #expect(options.map(\.title) == ["All years", "2026", "2025", "2019"])
        #expect(options.map(\.value) == [nil, 2026, 2025, 2019])
    }

    @Test("A selected year that is already a choice is not listed twice")
    func yearNotDuplicated() {
        let options = Screen.yearOptions(choices: [2026, 2025], selected: 2025)

        #expect(options.map(\.title) == ["All years", "2026", "2025"])
    }

    @Test("With all years selected nothing is added")
    func yearAllSelected() {
        let options = Screen.yearOptions(choices: [2026], selected: nil)

        #expect(options.map(\.value) == [nil, 2026])
    }

    @Test("With no choices there is All years and the selected year")
    func yearNoChoices() {
        #expect(Screen.yearOptions(choices: [], selected: 2026).map(\.title) == ["All years", "2026"])
        #expect(Screen.yearOptions(choices: [], selected: nil).map(\.title) == ["All years"])
    }

    @Test("Option ids are unique")
    func yearIdsUnique() {
        let ids = Screen.yearOptions(choices: [2026, 2025], selected: 2019).map(\.id)

        #expect(Set(ids).count == ids.count)
    }

    // MARK: Shipping

    @Test("Shipping options are All, Not tracked, Not shipped, Shipped, Delivered")
    func shippingOrder() {
        let options = Screen.shippingOptions()

        #expect(options.map(\.title) == ["All", "Not tracked", "Not shipped", "Shipped", "Delivered"])
        #expect(options.map(\.value) == [nil, .notTracked, .notShipped, .shipped, .delivered])
    }

    @Test("Shipping option titles are the status display names, in allCases order")
    func shippingUsesDisplayNames() {
        let titles = Screen.shippingOptions().dropFirst().map(\.title)

        #expect(Array(titles) == PurchaseShippingStatus.allCases.map(\.displayName))
    }

    // MARK: Recipient

    @Test("Recipient options are All people (nil), then the model's people in order")
    func recipientOrder() {
        let people = [
            PurchaseHistoryRecipient(id: "p2", name: "Sam"),
            PurchaseHistoryRecipient(id: "p1", name: "Alex")
        ]
        let options = Screen.recipientOptions(people)

        #expect(options.map(\.title) == ["All people", "Sam", "Alex"])
        #expect(options.map(\.value) == [nil, people[0], people[1]])
    }

    @Test("With no people there is only All people")
    func recipientEmpty() {
        #expect(Screen.recipientOptions([]).map(\.title) == ["All people"])
    }
}
