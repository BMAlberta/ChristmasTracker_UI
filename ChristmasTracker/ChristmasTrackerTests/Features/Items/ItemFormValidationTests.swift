//
//  ItemFormValidationTests.swift
//  ChristmasTrackerTests
//
//  Story I3c-B: the pure validation rules of the add and edit forms (Gate 1 addendum, D4).
//
//  Rules under test: name trimmed 1...200; description trimmed 1...2000 (REQUIRED by the
//  server); url and imageUrl empty after trimming (valid, sent as nil) or an absolute http or
//  https URL with a host of at most 2048 characters; price empty (valid) or parsed with
//  en_US_POSIX into a Decimal from 0 to 999999.99 with at most two fraction digits; quantity
//  1...999; priority 1...10.
//
//  Fails today because ItemFormValidation, ItemFormValidity and ItemFormCopy do not exist yet.
//

import Testing
import Foundation
@testable import ChristmasTracker

@Suite("Item form validation Tests")
struct ItemFormValidationTests {

    // MARK: - Factory

    /// Validates a form where every field is valid except the ones the test overrides.
    private func makeSUT(
        name: String = "Fake Gift",
        description: String = "A fake description",
        url: String = "",
        imageUrl: String = "",
        price: String = "",
        quantity: Int = 1,
        priority: Int = 5
    ) -> ItemFormValidity {
        ItemFormValidation.validate(
            name: name, description: description, url: url, imageUrl: imageUrl,
            priceText: price, quantity: quantity, priority: priority
        )
    }

    private func text(_ character: Character, count: Int) -> String {
        String(repeating: character, count: count)
    }

    private func url(ofLength length: Int) -> String {
        let prefix = "https://example.com/"
        return prefix + String(repeating: "a", count: length - prefix.count)
    }

    // MARK: - All valid

    @Test("A minimal valid form is valid and flags nothing")
    func minimalFormIsValid() {
        let validity = makeSUT()
        #expect(validity.isValid)
        #expect(!validity.nameInvalid)
        #expect(!validity.descriptionInvalid)
        #expect(!validity.urlInvalid)
        #expect(!validity.imageUrlInvalid)
        #expect(!validity.priceInvalid)
        #expect(!validity.quantityInvalid)
        #expect(!validity.priorityInvalid)
    }

    @Test("A fully filled form is valid")
    func fullFormIsValid() {
        let validity = makeSUT(url: "https://example.com/lamp", imageUrl: "http://example.com/lamp.png",
                               price: "19.99", quantity: 3, priority: 8)
        #expect(validity.isValid)
    }

    // MARK: - Name

    @Test("Name boundaries: 1 and 200 characters valid, empty, blank and 201 invalid")
    func nameBoundaries() {
        #expect(!makeSUT(name: "a").nameInvalid)
        #expect(!makeSUT(name: text("a", count: 200)).nameInvalid)
        #expect(makeSUT(name: "").nameInvalid)
        #expect(makeSUT(name: "   \n").nameInvalid)
        #expect(makeSUT(name: text("a", count: 201)).nameInvalid)
    }

    @Test("Name is measured after trimming")
    func nameTrimmed() {
        #expect(!makeSUT(name: "  " + text("a", count: 200) + "  ").nameInvalid)
        #expect(makeSUT(name: "  " + text("a", count: 201) + "  ").nameInvalid)
    }

    @Test("An invalid name makes the form invalid and flags only the name")
    func nameFlagsOnlyName() {
        let validity = makeSUT(name: "")
        #expect(!validity.isValid)
        #expect(validity.nameInvalid)
        #expect(!validity.descriptionInvalid && !validity.urlInvalid && !validity.imageUrlInvalid)
        #expect(!validity.priceInvalid && !validity.quantityInvalid && !validity.priorityInvalid)
    }

    // MARK: - Description

    @Test("Description boundaries: 1 and 2000 characters valid, empty, blank and 2001 invalid")
    func descriptionBoundaries() {
        #expect(!makeSUT(description: "a").descriptionInvalid)
        #expect(!makeSUT(description: text("a", count: 2000)).descriptionInvalid)
        #expect(makeSUT(description: "").descriptionInvalid)
        #expect(makeSUT(description: " \t\n ").descriptionInvalid)
        #expect(makeSUT(description: text("a", count: 2001)).descriptionInvalid)
    }

    @Test("An empty description makes the form invalid (the server requires it)")
    func descriptionRequired() {
        let validity = makeSUT(description: "")
        #expect(!validity.isValid)
        #expect(validity.descriptionInvalid)
        #expect(!validity.nameInvalid)
    }

    // MARK: - Quantity and priority

    @Test("Quantity boundaries 1...999", arguments: [(0, true), (1, false), (2, false), (999, false), (1000, true), (-1, true)])
    func quantityBoundaries(value: Int, invalid: Bool) {
        let validity = makeSUT(quantity: value)
        #expect(validity.quantityInvalid == invalid)
        #expect(validity.isValid == !invalid)
    }

    @Test("Priority boundaries 1...10", arguments: [(0, true), (1, false), (5, false), (10, false), (11, true), (-3, true)])
    func priorityBoundaries(value: Int, invalid: Bool) {
        let validity = makeSUT(priority: value)
        #expect(validity.priorityInvalid == invalid)
        #expect(validity.isValid == !invalid)
    }

    // MARK: - Price

    @Test("Valid prices", arguments: ["", "0", "0.00", "19.9", "19.99", "1234.50", "999999.99", "0.01", "5"])
    func validPrices(price: String) {
        let validity = makeSUT(price: price)
        #expect(!validity.priceInvalid, "'\(price)'")
        #expect(validity.isValid, "'\(price)'")
    }

    @Test("Invalid prices", arguments: [
        "19.999", "1000000", "1000000.00", "999999.995", "-1", "-0.01", "abc", "1e3", "1,5", "12abc", "$5", "1.2.3"
    ])
    func invalidPrices(price: String) {
        let validity = makeSUT(price: price)
        #expect(validity.priceInvalid, "'\(price)'")
        #expect(!validity.isValid, "'\(price)'")
    }

    // MARK: - parsePrice

    @Test("parsePrice returns the exact Decimal for valid prices",
          arguments: [("0", "0"), ("19.9", "19.9"), ("19.99", "19.99"), ("1234.50", "1234.50"), ("999999.99", "999999.99")])
    func parsePriceValid(text: String, expected: String) {
        #expect(ItemFormValidation.parsePrice(text) == ItemFixtures.decimal(expected))
    }

    @Test("parsePrice returns nil for empty and invalid prices",
          arguments: ["", "19.999", "1000000", "-1", "abc", "1e3", "1,5"])
    func parsePriceInvalid(text: String) {
        #expect(ItemFormValidation.parsePrice(text) == nil, "'\(text)'")
    }

    // MARK: - URLs

    @Test("Empty and whitespace url and imageUrl are valid (sent as nil)", arguments: ["", "   ", "\n"])
    func emptyUrlsAreValid(value: String) {
        let validity = makeSUT(url: value, imageUrl: value)
        #expect(!validity.urlInvalid)
        #expect(!validity.imageUrlInvalid)
    }

    @Test("Absolute http and https URLs with a host are valid",
          arguments: ["https://example.com", "http://example.com", "https://example.com/a/b?c=d#e", "  https://example.com/x  "])
    func validUrls(value: String) {
        #expect(!makeSUT(url: value).urlInvalid, "url '\(value)'")
        #expect(!makeSUT(imageUrl: value).imageUrlInvalid, "imageUrl '\(value)'")
    }

    @Test("Other schemes, relative values, hostless and non-URL text are invalid",
          arguments: ["ftp://example.com", "example.com", "www.example.com", "https://", "http:///path", "not a url",
                      "javascript:alert(1)", "file:///etc/hosts", "/relative/path", "mailto:a@example.com"])
    func invalidUrls(value: String) {
        let urlValidity = makeSUT(url: value)
        #expect(urlValidity.urlInvalid, "url '\(value)'")
        #expect(!urlValidity.isValid, "url '\(value)'")
        let imageValidity = makeSUT(imageUrl: value)
        #expect(imageValidity.imageUrlInvalid, "imageUrl '\(value)'")
        #expect(!imageValidity.isValid, "imageUrl '\(value)'")
    }

    @Test("URL length boundary: 2048 characters valid, 2049 invalid")
    func urlLengthBoundary() {
        #expect(!makeSUT(url: url(ofLength: 2048)).urlInvalid)
        #expect(makeSUT(url: url(ofLength: 2049)).urlInvalid)
        #expect(!makeSUT(imageUrl: url(ofLength: 2048)).imageUrlInvalid)
        #expect(makeSUT(imageUrl: url(ofLength: 2049)).imageUrlInvalid)
    }

    @Test("A bad url flags only url and a bad imageUrl flags only imageUrl")
    func urlFlagsAreIndependent() {
        let badUrl = makeSUT(url: "nope")
        #expect(badUrl.urlInvalid && !badUrl.imageUrlInvalid)
        let badImage = makeSUT(imageUrl: "nope")
        #expect(badImage.imageUrlInvalid && !badImage.urlInvalid)
    }

    // MARK: - Several errors at once

    @Test("Several bad fields are all flagged and the form is invalid")
    func severalErrors() {
        let validity = makeSUT(name: "", description: "", url: "x", imageUrl: "y", price: "z", quantity: 0, priority: 0)
        #expect(!validity.isValid)
        #expect(validity.nameInvalid && validity.descriptionInvalid)
        #expect(validity.urlInvalid && validity.imageUrlInvalid)
        #expect(validity.priceInvalid && validity.quantityInvalid && validity.priorityInvalid)
    }

    // MARK: - Copy

    @Test("The off-list sentence is the pinned plain sentence and never mentions a role")
    func offListSentence() {
        #expect(ItemFormCopy.offListSentence == "This item will be hidden from the recipient.")
        let lowered = ItemFormCopy.offListSentence.lowercased()
        #expect(!lowered.contains("member"))
        #expect(!lowered.contains("owner"))
    }
}
