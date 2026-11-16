//
//  ItemUpdateInputClearingTests.swift
//  ChristmasTrackerTests
//
//  IMG1-P3 (decision 17): makeUpdateInput sends url and imageUrl ONLY when the user changed that
//  field (trimmed new value differs from the trimmed original; a nil original equals empty).
//  Clearing a field that had a value sends "" (never nil); unchanged fields are nil (omitted).
//
//  Covers ItemFormValidation.makeUpdateInput and UpdateItemInput.
//

import Testing
import Foundation
@testable import ChristmasTracker

@Suite("Item update input clearing Tests")
struct ItemUpdateInputClearingTests {

    enum Field: String, CaseIterable, CustomStringConvertible {
        case url, imageUrl
        var description: String { rawValue }
    }

    private func item(
        url: String? = "https://example.com/lamp", imageUrl: String? = "https://example.com/lamp.png"
    ) -> ListItem {
        ItemFixtures.item(name: "Fake Lamp", description: "A fake lamp", url: url, imageUrl: imageUrl,
                          price: nil, quantity: 2, priority: 5)
    }

    private func makeSUT(
        from original: ListItem,
        name: String = "Fake Lamp",
        url: String? = nil,
        imageUrl: String? = nil
    ) -> UpdateItemInput? {
        ItemFormValidation.makeUpdateInput(
            original: original, name: name, description: "A fake lamp",
            url: url ?? original.url ?? "", imageUrl: imageUrl ?? original.imageUrl ?? "",
            priceText: "", quantity: 2, priority: 5
        )
    }

    private func sent(_ input: UpdateItemInput?, _ field: Field) -> String? {
        switch field {
        case .url: input?.url
        case .imageUrl: input?.imageUrl
        }
    }

    /// The form with `field` replaced by `text` and the other field untouched.
    private func make(
        _ original: ListItem, field: Field, text: String, name: String = "Fake Lamp"
    ) -> UpdateItemInput? {
        switch field {
        case .url: makeSUT(from: original, name: name, url: text)
        case .imageUrl: makeSUT(from: original, name: name, imageUrl: text)
        }
    }

    // MARK: - Per field

    @Test("A changed value is sent, trimmed", arguments: Field.allCases)
    func changedIsSent(field: Field) {
        let input = make(item(), field: field, text: "  https://example.com/new  ")
        #expect(sent(input, field) == "https://example.com/new")
    }

    @Test("An unchanged value (even with padding) is not sent", arguments: Field.allCases)
    func unchangedIsNotSent(field: Field) {
        let original = item()
        let same = field == .url ? original.url : original.imageUrl
        let input = make(original, field: field, text: " \(same ?? "") ", name: "Renamed")
        #expect(input?.name == "Renamed")
        #expect(sent(input, field) == nil)
    }

    @Test(
        "Clearing a field that had a value sends an empty string, never nil",
        arguments: Field.allCases, ["", "   ", "\n"]
    )
    func clearedSendsEmptyString(field: Field, blank: String) throws {
        let input = try #require(make(item(), field: field, text: blank))
        #expect(sent(input, field) == "")
        #expect(!input.isEmpty, "a clear alone is a change")
    }

    @Test("Clearing next to another change sends the empty string and the change", arguments: Field.allCases)
    func clearedNextToChange(field: Field) throws {
        let input = try #require(make(item(), field: field, text: "", name: "Renamed"))
        #expect(input.name == "Renamed")
        #expect(sent(input, field) == "")
    }

    @Test("An empty field with a nil original is not sent", arguments: Field.allCases)
    func emptyStaysEmpty(field: Field) {
        let bare = item(url: nil, imageUrl: nil)
        let input = make(bare, field: field, text: "", name: "Renamed")
        #expect(input?.name == "Renamed")
        #expect(sent(input, field) == nil)
    }

    @Test("An empty field with an empty-string original is not sent", arguments: Field.allCases)
    func emptyOriginalString(field: Field) {
        let bare = item(url: "", imageUrl: "")
        let input = make(bare, field: field, text: "  ", name: "Renamed")
        #expect(sent(input, field) == nil)
    }

    @Test("A bare untouched form produces no update", arguments: Field.allCases)
    func bareUntouchedIsNil(field: Field) {
        #expect(make(item(url: nil, imageUrl: nil), field: field, text: "") == nil)
    }

    @Test("A first value on a field that had none is a change", arguments: Field.allCases)
    func firstValueIsSent(field: Field) {
        let input = make(item(url: nil, imageUrl: nil), field: field, text: "https://example.com/first")
        #expect(sent(input, field) == "https://example.com/first")
    }

    // MARK: - Image specifics

    @Test("An unchanged legacy http imageUrl is not sent while another field changes")
    func legacyHttpImageNotSent() {
        let legacy = item(imageUrl: "http://example.com/legacy.png")
        let input = makeSUT(from: legacy, name: "Renamed")
        #expect(input?.name == "Renamed")
        #expect(input?.imageUrl == nil)
        #expect(input?.url == nil)
    }

    @Test("An Add-image fill (original nil, new https value) counts as a change")
    func addImageFillIsSent() {
        let bare = item(imageUrl: nil)
        let input = makeSUT(from: bare, imageUrl: "https://images.example.test/preview.jpg")
        #expect(input?.imageUrl == "https://images.example.test/preview.jpg")
        #expect(input?.url == nil)
    }

    @Test("Clearing both fields sends two empty strings")
    func clearingBoth() throws {
        let input = try #require(makeSUT(from: item(), url: "", imageUrl: ""))
        #expect(input.url == "")
        #expect(input.imageUrl == "")
    }

    @Test("An invalid changed value still produces no update")
    func invalidStillNil() {
        #expect(make(item(), field: .url, text: "nope") == nil)
        #expect(make(item(), field: .imageUrl, text: "http://example.com/x.png") == nil)
    }
}
