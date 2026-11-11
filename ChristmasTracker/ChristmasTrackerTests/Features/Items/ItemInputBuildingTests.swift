//
//  ItemInputBuildingTests.swift
//  ChristmasTrackerTests
//
//  Story I3c-B: building the request inputs from form text.
//   - makeCreateInput: nil when invalid, otherwise trimmed values, nil for empty optionals,
//     a Decimal price, and NEVER an offList (the server derives it).
//   - makeUpdateInput: nil when invalid or when nothing differs from the original; only the
//     changed fields are non-nil; clearing an optional field (url, imageUrl, price) is not a
//     change because the generated update body cannot clear a field.
//
//  The memberwise initialiser of UpdateItemInput is used once, for the isEmpty checks; its
//  argument order is the declaration order in the Gate 1 addendum.
//
//  Fails today because CreateItemInput, UpdateItemInput and the make functions do not exist yet.
//

import Testing
import Foundation
@testable import ChristmasTracker

@Suite("Item input building Tests")
struct ItemInputBuildingTests {

    // MARK: - Factories

    private func makeCreate(
        name: String = "Fake Gift",
        description: String = "A fake description",
        url: String = "",
        imageUrl: String = "",
        price: String = "",
        quantity: Int = 1,
        priority: Int = 5
    ) -> CreateItemInput? {
        ItemFormValidation.makeCreateInput(
            name: name, description: description, url: url, imageUrl: imageUrl,
            priceText: price, quantity: quantity, priority: priority
        )
    }

    private var original: ListItem {
        ItemFixtures.item(
            name: "Fake Lamp", description: "A fake lamp",
            url: "https://example.com/lamp", imageUrl: "https://example.com/lamp.png",
            price: ItemFixtures.decimal("19.99"), quantity: 2, priority: 5
        )
    }

    /// The form as it looks when the user has not touched anything.
    private func makeUpdate(
        name: String = "Fake Lamp",
        description: String = "A fake lamp",
        url: String = "https://example.com/lamp",
        imageUrl: String = "https://example.com/lamp.png",
        price: String = "19.99",
        quantity: Int = 2,
        priority: Int = 5,
        from item: ListItem? = nil
    ) -> UpdateItemInput? {
        ItemFormValidation.makeUpdateInput(
            original: item ?? original,
            name: name, description: description, url: url, imageUrl: imageUrl,
            priceText: price, quantity: quantity, priority: priority
        )
    }

    // MARK: - makeCreateInput

    @Test("A full valid form produces the trimmed input")
    func createFull() throws {
        let input = try #require(makeCreate(
            name: "  Fake Lamp \n", description: "\tA fake lamp  ",
            url: " https://example.com/lamp ", imageUrl: "http://example.com/lamp.png ",
            price: "19.99", quantity: 3, priority: 8
        ))
        #expect(input.name == "Fake Lamp")
        #expect(input.description == "A fake lamp")
        #expect(input.url == "https://example.com/lamp")
        #expect(input.imageUrl == "http://example.com/lamp.png")
        #expect(input.expectedUnitPrice == ItemFixtures.decimal("19.99"))
        #expect(input.quantityRequested == 3)
        #expect(input.priority == 8)
    }

    @Test("Empty and blank optionals become nil", arguments: ["", "   ", "\n\t"])
    func createEmptyOptionalsAreNil(blank: String) throws {
        let input = try #require(makeCreate(url: blank, imageUrl: blank, price: blank))
        #expect(input.url == nil)
        #expect(input.imageUrl == nil)
        #expect(input.expectedUnitPrice == nil)
    }

    @Test("Price text maps to the exact Decimal", arguments: ["0", "19.9", "19.99", "1234.50", "999999.99"])
    func createPriceDecimal(price: String) throws {
        let input = try #require(makeCreate(price: price))
        #expect(input.expectedUnitPrice == ItemFixtures.decimal(price))
    }

    @Test("An invalid form produces no input", arguments: [
        ("", "d", "", "", "", 1, 5),
        ("n", "", "", "", "", 1, 5),
        ("n", "d", "nope", "", "", 1, 5),
        ("n", "d", "", "nope", "", 1, 5),
        ("n", "d", "", "", "19.999", 1, 5),
        ("n", "d", "", "", "", 0, 5),
        ("n", "d", "", "", "", 1, 11)
    ])
    func createInvalidIsNil(name: String, description: String, url: String, imageUrl: String,
                            price: String, quantity: Int, priority: Int) {
        #expect(makeCreate(name: name, description: description, url: url, imageUrl: imageUrl,
                           price: price, quantity: quantity, priority: priority) == nil)
    }

    @Test("The create input has no offList member and cannot be given one")
    func createHasNoOffList() throws {
        let input = try #require(makeCreate(price: "5"))
        let labels = Mirror(reflecting: input).children.compactMap(\.label)
        #expect(!labels.contains("offList"))
        #expect(Set(labels) == ["name", "description", "url", "imageUrl", "expectedUnitPrice",
                                "quantityRequested", "priority"])
    }

    @Test("Equal forms give equal inputs")
    func createEquatable() {
        #expect(makeCreate(price: "5") == makeCreate(price: "5"))
        #expect(makeCreate(price: "5") != makeCreate(price: "6"))
    }

    // MARK: - makeUpdateInput: nothing changed

    @Test("An untouched form produces no update")
    func updateUntouchedIsNil() {
        #expect(makeUpdate() == nil)
    }

    @Test("Whitespace-only differences are not changes")
    func updateTrimmedEqualIsNil() {
        #expect(makeUpdate(name: "  Fake Lamp  ", description: " A fake lamp\n",
                           url: " https://example.com/lamp ", imageUrl: "https://example.com/lamp.png ",
                           price: " 19.99") == nil)
    }

    @Test("Writing the same price with a different shape is not a change", arguments: ["19.990", "19.99"])
    func updateSamePriceIsNil(price: String) {
        #expect(makeUpdate(price: price) == nil)
    }

    @Test("Clearing url, imageUrl or price is not a change (clearing is not offered)")
    func updateClearingIsNotAChange() {
        #expect(makeUpdate(url: "") == nil)
        #expect(makeUpdate(imageUrl: "") == nil)
        #expect(makeUpdate(price: "") == nil)
        #expect(makeUpdate(url: "  ", imageUrl: "\n", price: "  ") == nil)
    }

    @Test("Clearing optionals next to a real change leaves them nil in the update")
    func updateClearingNextToChange() throws {
        let input = try #require(makeUpdate(name: "New name", url: "", imageUrl: "", price: ""))
        #expect(input.name == "New name")
        #expect(input.url == nil)
        #expect(input.imageUrl == nil)
        #expect(input.expectedUnitPrice == nil)
    }

    // MARK: - makeUpdateInput: changes

    @Test("Only the changed name is set")
    func updateNameOnly() throws {
        let input = try #require(makeUpdate(name: "  New name "))
        #expect(input.name == "New name")
        #expect(input.description == nil)
        #expect(input.url == nil)
        #expect(input.imageUrl == nil)
        #expect(input.expectedUnitPrice == nil)
        #expect(input.quantityRequested == nil)
        #expect(input.priority == nil)
        #expect(!input.isEmpty)
    }

    @Test("Only the changed description is set")
    func updateDescriptionOnly() throws {
        let input = try #require(makeUpdate(description: "New description"))
        #expect(input.description == "New description")
        #expect(input.name == nil)
        #expect(input.url == nil && input.imageUrl == nil)
        #expect(input.expectedUnitPrice == nil && input.quantityRequested == nil && input.priority == nil)
    }

    @Test("Only the changed url and imageUrl are set")
    func updateUrlsOnly() throws {
        let input = try #require(makeUpdate(url: "https://example.com/new", imageUrl: "https://example.com/new.png"))
        #expect(input.url == "https://example.com/new")
        #expect(input.imageUrl == "https://example.com/new.png")
        #expect(input.name == nil && input.description == nil)
        #expect(input.expectedUnitPrice == nil && input.quantityRequested == nil && input.priority == nil)
    }

    @Test("Only the changed price is set, as an exact Decimal")
    func updatePriceOnly() throws {
        let input = try #require(makeUpdate(price: "24.5"))
        #expect(input.expectedUnitPrice == ItemFixtures.decimal("24.5"))
        #expect(input.name == nil && input.description == nil && input.url == nil && input.imageUrl == nil)
        #expect(input.quantityRequested == nil && input.priority == nil)
    }

    @Test("Only the changed quantity is set")
    func updateQuantityOnly() throws {
        let input = try #require(makeUpdate(quantity: 6))
        #expect(input.quantityRequested == 6)
        #expect(input.priority == nil)
        #expect(input.name == nil && input.description == nil && input.expectedUnitPrice == nil)
    }

    @Test("Only the changed priority is set")
    func updatePriorityOnly() throws {
        let input = try #require(makeUpdate(priority: 9))
        #expect(input.priority == 9)
        #expect(input.quantityRequested == nil)
        #expect(input.name == nil && input.description == nil && input.expectedUnitPrice == nil)
    }

    @Test("Several changes are all set and the rest stay nil")
    func updateSeveral() throws {
        let input = try #require(makeUpdate(name: "A", price: "1", quantity: 3))
        #expect(input.name == "A")
        #expect(input.expectedUnitPrice == ItemFixtures.decimal("1"))
        #expect(input.quantityRequested == 3)
        #expect(input.description == nil && input.url == nil && input.imageUrl == nil && input.priority == nil)
    }

    @Test("Adding a value to an originally empty optional is a change")
    func updateAddingOptionals() throws {
        let bare = ItemFixtures.item(name: "Fake Lamp", description: "A fake lamp", url: nil, imageUrl: nil,
                                     price: nil, quantity: 2, priority: 5)
        let input = try #require(makeUpdate(url: "https://example.com/lamp", imageUrl: "https://example.com/i.png",
                                            price: "5", from: bare))
        #expect(input.url == "https://example.com/lamp")
        #expect(input.imageUrl == "https://example.com/i.png")
        #expect(input.expectedUnitPrice == ItemFixtures.decimal("5"))
        #expect(input.name == nil)
    }

    @Test("An untouched form for an item without optionals produces no update")
    func updateBareUntouchedIsNil() {
        let bare = ItemFixtures.item(name: "Fake Lamp", description: "A fake lamp", url: nil, imageUrl: nil,
                                     price: nil, quantity: 2, priority: 5)
        #expect(makeUpdate(url: "", imageUrl: "", price: "", from: bare) == nil)
    }

    // MARK: - makeUpdateInput: invalid

    @Test("An invalid form produces no update even with a real change", arguments: [
        ("", "A fake lamp", "19.99", 2, 5),
        ("Fake Lamp", "", "19.99", 2, 5),
        ("Fake Lamp", "A fake lamp", "19.999", 2, 5),
        ("Fake Lamp", "A fake lamp", "19.99", 0, 5),
        ("Fake Lamp", "A fake lamp", "19.99", 2, 11)
    ])
    func updateInvalidIsNil(name: String, description: String, price: String, quantity: Int, priority: Int) {
        #expect(makeUpdate(name: name, description: description, price: price,
                           quantity: quantity, priority: priority) == nil)
    }

    @Test("An invalid url or imageUrl produces no update")
    func updateInvalidUrlIsNil() {
        #expect(makeUpdate(name: "Changed", url: "nope") == nil)
        #expect(makeUpdate(name: "Changed", imageUrl: "nope") == nil)
    }

    // MARK: - UpdateItemInput.isEmpty

    private func input(
        name: String? = nil, description: String? = nil, url: String? = nil, imageUrl: String? = nil,
        price: Decimal? = nil, quantity: Int? = nil, priority: Int? = nil
    ) -> UpdateItemInput {
        UpdateItemInput(name: name, description: description, url: url, imageUrl: imageUrl,
                        expectedUnitPrice: price, quantityRequested: quantity, priority: priority)
    }

    @Test("An update with every field nil is empty")
    func isEmptyWhenAllNil() {
        #expect(input().isEmpty)
    }

    @Test("An update with any single field set is not empty")
    func isNotEmptyWithAnyField() {
        #expect(!input(name: "a").isEmpty)
        #expect(!input(description: "a").isEmpty)
        #expect(!input(url: "https://example.com").isEmpty)
        #expect(!input(imageUrl: "https://example.com").isEmpty)
        #expect(!input(price: ItemFixtures.decimal("1")).isEmpty)
        #expect(!input(quantity: 1).isEmpty)
        #expect(!input(priority: 1).isEmpty)
    }
}
