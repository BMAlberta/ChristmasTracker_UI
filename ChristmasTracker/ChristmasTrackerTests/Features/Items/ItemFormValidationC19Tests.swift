//
//  ItemFormValidationC19Tests.swift
//  ChristmasTrackerTests
//
//  Story IMG1-P2: URL validation matches C19. url is http or https, imageUrl is https only, both
//  reject userinfo, whitespace and more than 2048 characters. On Edit, a field that equals its
//  stored original value is not validated (decision 17), so an unchanged legacy value neither
//  blocks saving nor shows an invalid flag; a changed field is validated.
//

import Testing
import Foundation
@testable import ChristmasTracker

@Suite("Item form validation C19 Tests")
struct ItemFormValidationC19Tests {

    // MARK: - Factory

    private func validate(
        url: String = "",
        imageUrl: String = "",
        originalUrl: String? = nil,
        originalImageUrl: String? = nil
    ) -> ItemFormValidity {
        ItemFormValidation.validate(
            name: "Fake Gift", description: "A fake description", url: url, imageUrl: imageUrl,
            priceText: "", quantity: 1, priority: 5,
            originalUrl: originalUrl, originalImageUrl: originalImageUrl
        )
    }

    private func update(
        original: ListItem,
        name: String = "Fake Gift",
        url: String = "",
        imageUrl: String = ""
    ) -> UpdateItemInput? {
        ItemFormValidation.makeUpdateInput(
            original: original, name: name, description: "A fake description", url: url,
            imageUrl: imageUrl, priceText: "", quantity: 1, priority: 5
        )
    }

    private func create(url: String = "", imageUrl: String = "") -> CreateItemInput? {
        ItemFormValidation.makeCreateInput(
            name: "Fake Gift", description: "A fake description", url: url, imageUrl: imageUrl,
            priceText: "", quantity: 1, priority: 5
        )
    }

    private func value(ofLength length: Int, scheme: String = "https") -> String {
        let prefix = "\(scheme)://example.com/"
        return prefix + String(repeating: "a", count: length - prefix.count)
    }

    // MARK: - url

    @Test("url accepts http and https", arguments: ["http://example.com", "https://example.com/a?b=c"])
    func urlValid(value: String) {
        #expect(!validate(url: value).urlInvalid)
    }

    @Test("url rejects bad values", arguments: [
        "ftp://example.com", "javascript:alert(1)", "example.com", "https://", "http:///path",
        "https://exa mple.com", "https://example.com/a b",
        "https://user:pass@example.com", "https://user@example.com", "http://user@example.com/x"
    ])
    func urlInvalid(value: String) {
        #expect(validate(url: value).urlInvalid, "'\(value)'")
    }

    @Test("url length: 2048 valid, 2049 invalid")
    func urlLength() {
        #expect(!validate(url: value(ofLength: 2048, scheme: "http")).urlInvalid)
        #expect(validate(url: value(ofLength: 2049, scheme: "http")).urlInvalid)
    }

    // MARK: - imageUrl

    @Test("imageUrl accepts https only")
    func imageUrlHttpsOnly() {
        #expect(!validate(imageUrl: "https://example.com/a.png").imageUrlInvalid)
        #expect(validate(imageUrl: "http://example.com/a.png").imageUrlInvalid)
    }

    @Test("imageUrl rejects bad values", arguments: [
        "http://example.com/a.png", "ftp://example.com", "javascript:alert(1)", "example.com", "https://",
        "https:///path", "https://exa mple.com", "https://user:pass@example.com/a.png",
        "https://user@example.com/a.png"
    ])
    func imageUrlInvalid(value: String) {
        #expect(validate(imageUrl: value).imageUrlInvalid, "'\(value)'")
    }

    @Test("imageUrl length: 2048 valid, 2049 invalid")
    func imageUrlLength() {
        #expect(!validate(imageUrl: value(ofLength: 2048)).imageUrlInvalid)
        #expect(validate(imageUrl: value(ofLength: 2049)).imageUrlInvalid)
    }

    @Test("Empty is valid for both fields", arguments: ["", "  "])
    func emptyValid(value: String) {
        let validity = validate(url: value, imageUrl: value)
        #expect(!validity.urlInvalid && !validity.imageUrlInvalid)
    }

    // MARK: - Builders

    @Test("The create builder rejects an http imageUrl and accepts an https one")
    func createBuilderImage() {
        #expect(create(imageUrl: "http://example.com/a.png") == nil)
        #expect(create(imageUrl: "https://example.com/a.png")?.imageUrl == "https://example.com/a.png")
    }

    @Test("The create builder rejects userinfo in url")
    func createBuilderUserinfo() {
        #expect(create(url: "https://user:pass@example.com") == nil)
    }

    @Test("The update builder rejects a changed http imageUrl")
    func updateBuilderHttpImage() {
        let original = ItemFixtures.item()
        #expect(update(original: original, imageUrl: "http://example.com/a.png") == nil)
    }

    // MARK: - Decision 17: unchanged legacy values

    @Test("An unchanged legacy http imageUrl is valid and is not sent")
    func legacyImageUnchanged() {
        let legacy = "http://example.com/old.png"
        let original = ItemFixtures.item(imageUrl: legacy)
        #expect(!validate(imageUrl: legacy, originalImageUrl: legacy).imageUrlInvalid)
        #expect(validate(imageUrl: legacy, originalImageUrl: legacy).isValid)
        let input = update(original: original, name: "Renamed", imageUrl: legacy)
        #expect(input?.name == "Renamed")
        #expect(input?.imageUrl == nil)
    }

    @Test("An unchanged legacy value compared after trimming is still not validated")
    func legacyImageUnchangedPadded() {
        let legacy = "http://example.com/old.png"
        #expect(!validate(imageUrl: "  \(legacy) ", originalImageUrl: legacy).imageUrlInvalid)
        #expect(!validate(imageUrl: legacy, originalImageUrl: " \(legacy)\n").imageUrlInvalid)
    }

    @Test("A legacy http imageUrl changed to another http value is invalid")
    func legacyImageChanged() {
        let legacy = "http://example.com/old.png"
        let original = ItemFixtures.item(imageUrl: legacy)
        #expect(validate(imageUrl: "http://example.com/new.png", originalImageUrl: legacy).imageUrlInvalid)
        #expect(update(original: original, name: "Renamed", imageUrl: "http://example.com/new.png") == nil)
    }

    @Test("A legacy http imageUrl changed to https is valid and sent")
    func legacyImageChangedToHttps() {
        let original = ItemFixtures.item(imageUrl: "http://example.com/old.png")
        let input = update(original: original, imageUrl: "https://example.com/new.png")
        #expect(input?.imageUrl == "https://example.com/new.png")
    }

    @Test("An unchanged legacy url with userinfo is valid and is not sent")
    func legacyUrlUnchanged() {
        let legacy = "https://user:pass@example.com/p"
        let original = ItemFixtures.item(url: legacy)
        #expect(!validate(url: legacy, originalUrl: legacy).urlInvalid)
        let input = update(original: original, name: "Renamed", url: legacy)
        #expect(input?.name == "Renamed")
        #expect(input?.url == nil)
    }

    @Test("A legacy url with userinfo changed to another userinfo value is invalid")
    func legacyUrlChanged() {
        let legacy = "https://user:pass@example.com/p"
        let original = ItemFixtures.item(url: legacy)
        #expect(validate(url: "https://user:pass@example.com/q", originalUrl: legacy).urlInvalid)
        #expect(update(original: original, name: "Renamed", url: "https://user:pass@example.com/q") == nil)
    }

    @Test("Without originals everything is validated")
    func noOriginalsValidatesAll() {
        #expect(validate(imageUrl: "http://example.com/a.png").imageUrlInvalid)
        #expect(validate(url: "https://u@example.com").urlInvalid)
    }

    @Test("Padded whitespace around a valid value is trimmed")
    func paddedValueTrimmed() {
        #expect(validate(url: "  https://example.com/x  ", imageUrl: "\nhttps://example.com/y.png ").isValid)
        #expect(create(url: "  https://example.com/x  ")?.url == "https://example.com/x")
    }
}
