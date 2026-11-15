//
//  ItemImageFillStateTests.swift
//  ChristmasTrackerTests
//
//  IMG1-P3: the pure decision table of the link-preview image fill (decisions 1 to 5): when a
//  lookup starts, how tokens order lookups, and when a finished lookup may fill the image field.
//
//  Covers ItemImageFillState, ItemFormMode, ItemImageSource and ItemImageLookup.
//

import Testing
import Foundation
@testable import ChristmasTracker

@Suite("Item image fill state Tests")
struct ItemImageFillStateTests {

    private static let page = "https://shop.example.test/p/1"
    private static let otherPage = "https://shop.example.test/p/2"
    private static let image = "https://images.example.test/a.jpg"
    private static let otherImage = "https://images.example.test/b.jpg"

    // MARK: - Factory

    private func makeSUT(mode: ItemFormMode = .add, initialImageUrl: String = "") -> ItemImageFillState {
        ItemImageFillState(mode: mode, initialImageUrl: initialImageUrl)
    }

    /// Starts a lookup for `url` (image text blank) and finishes it with `result`; returns the fill.
    @discardableResult
    private func fill(_ state: inout ItemImageFillState, url: String = page, result: String = image) throws -> String {
        let lookupStarted = state.urlEditingFinished(url: url, imageUrl: "")
        let lookup = try #require(lookupStarted)
        let filled = state.lookupFinished(lookup, result: result, url: url, imageUrl: "")
        return try #require(filled)
    }

    private func longUrl(length: Int) -> String {
        let prefix = "https://shop.example.test/"
        return prefix + String(repeating: "a", count: length - prefix.count)
    }

    // MARK: - Initial state

    @Test("A blank initial image starts empty, a stored one starts typed", arguments: [
        ("", ItemImageSource.empty), ("   ", .empty), ("\n", .empty),
        ("https://images.example.test/stored.jpg", .typed), (" https://images.example.test/stored.jpg ", .typed)
    ])
    func initialSource(initial: String, expected: ItemImageSource) {
        let state = makeSUT(initialImageUrl: initial)
        #expect(state.source == expected)
        #expect(state.inFlight == nil)
        #expect(!state.isLooking)
    }

    // MARK: - Add mode: when a call starts

    @Test("Add with an empty image and a valid url starts a lookup for the trimmed url")
    func addEmptyImageCalls() throws {
        var state = makeSUT()
        let lookupStarted = state.urlEditingFinished(url: Self.page, imageUrl: "")
        let lookup = try #require(lookupStarted)
        #expect(lookup.url == Self.page)
        #expect(state.inFlight == lookup)
        #expect(state.isLooking)
    }

    @Test("A padded valid url is trimmed and called")
    func paddedUrlIsTrimmed() throws {
        var state = makeSUT()
        let lookupStarted = state.urlEditingFinished(url: "  \(Self.page)\n", imageUrl: "  ")
        let lookup = try #require(lookupStarted)
        #expect(lookup.url == Self.page)
    }

    @Test("Add with a fetched image and a NEW url calls again")
    func addFetchedNewUrlCalls() throws {
        var state = makeSUT()
        let filled = try fill(&state)
        let lookup = state.urlEditingFinished(url: Self.otherPage, imageUrl: filled)
        #expect(lookup?.url == Self.otherPage)
    }

    @Test("Add with a fetched image and the SAME url makes no call")
    func addFetchedSameUrlNoCall() throws {
        var state = makeSUT()
        let filled = try fill(&state)
        #expect(state.urlEditingFinished(url: Self.page, imageUrl: filled) == nil)
        #expect(state.source == .fetched)
    }

    @Test("Add with a typed image makes no call")
    func addTypedNoCall() {
        var state = makeSUT()
        state.imageTextChanged(to: "https://images.example.test/mine.jpg")
        #expect(state.source == .typed)
        #expect(state.urlEditingFinished(url: Self.page, imageUrl: "https://images.example.test/mine.jpg") == nil)
        #expect(state.inFlight == nil)
    }

    @Test("The same url again after a nil result makes no repeat call")
    func noRepeatAfterNil() throws {
        var state = makeSUT()
        let lookupStarted = state.urlEditingFinished(url: Self.page, imageUrl: "")
        let lookup = try #require(lookupStarted)
        #expect(state.lookupFinished(lookup, result: nil, url: Self.page, imageUrl: "") == nil)
        #expect(state.urlEditingFinished(url: Self.page, imageUrl: "") == nil)
    }

    @Test("The same url while its lookup is still in flight makes no second call")
    func noRepeatWhileInFlight() throws {
        var state = makeSUT()
        let firstStarted = state.urlEditingFinished(url: Self.page, imageUrl: "")
        let first = try #require(firstStarted)
        #expect(state.urlEditingFinished(url: Self.page, imageUrl: "") == nil)
        #expect(state.inFlight == first)
    }

    // MARK: - Edit mode: when a call starts

    @Test("Edit with an empty image and a changed url calls")
    func editEmptyChangedCalls() {
        var state = makeSUT(mode: .edit(savedUrl: "https://shop.example.test/old"))
        #expect(state.urlEditingFinished(url: Self.page, imageUrl: "")?.url == Self.page)
    }

    @Test("Edit with an empty image and the saved url (even padded) makes no call", arguments: ["", "  ", "\n"])
    func editEmptySavedUrlNoCall(padding: String) {
        var state = makeSUT(mode: .edit(savedUrl: " \(Self.page) "))
        #expect(state.urlEditingFinished(url: padding + Self.page + padding, imageUrl: "") == nil)
        #expect(state.inFlight == nil)
    }

    @Test("Edit with a stored image makes no call even for a changed url")
    func editStoredImageNoCall() {
        let stored = "https://images.example.test/stored.jpg"
        var state = makeSUT(mode: .edit(savedUrl: "https://shop.example.test/old"), initialImageUrl: stored)
        #expect(state.source == .typed)
        #expect(state.urlEditingFinished(url: Self.page, imageUrl: stored) == nil)
    }

    @Test("Edit with no saved url and a newly entered valid url and an empty image calls")
    func editNoSavedUrlCalls() {
        var state = makeSUT(mode: .edit(savedUrl: nil))
        #expect(state.urlEditingFinished(url: Self.page, imageUrl: "")?.url == Self.page)
    }

    // MARK: - Invalid urls

    @Test("Invalid urls make no call and change no state", arguments: [
        "", "   ", "ftp://shop.example.test/p", "javascript:alert(1)", "https://", "http:///path",
        "https://user:pw@shop.example.test/p", "https://user@shop.example.test/p",
        "https://shop.example.test/a b", "shop.example.test/p", "not a url"
    ])
    func invalidUrlNoCall(value: String) {
        var add = makeSUT()
        let addBefore = add
        #expect(add.urlEditingFinished(url: value, imageUrl: "") == nil)
        #expect(add == addBefore)

        var edit = makeSUT(mode: .edit(savedUrl: nil))
        let editBefore = edit
        #expect(edit.urlEditingFinished(url: value, imageUrl: "") == nil)
        #expect(edit == editBefore)
    }

    @Test("An url of 2048 characters calls and one of 2049 does not")
    func urlLengthBoundary() {
        var state = makeSUT()
        #expect(state.urlEditingFinished(url: longUrl(length: 2049), imageUrl: "") == nil)
        #expect(state.urlEditingFinished(url: longUrl(length: 2048), imageUrl: "") != nil)
    }

    // MARK: - Tokens

    @Test("Tokens strictly increase and a second lookup supersedes the first, whose result is dropped")
    func tokensIncreaseAndSupersede() throws {
        var state = makeSUT()
        let firstStarted = state.urlEditingFinished(url: Self.page, imageUrl: "")
        let first = try #require(firstStarted)
        let secondStarted = state.urlEditingFinished(url: Self.otherPage, imageUrl: "")
        let second = try #require(secondStarted)

        #expect(second.token > first.token)
        #expect(state.inFlight == second)

        let stale = state.lookupFinished(first, result: Self.image, url: Self.otherPage, imageUrl: "")
        #expect(stale == nil)
        #expect(state.inFlight == second, "a stale result leaves the state unchanged")
        #expect(state.source == .empty)

        #expect(state.lookupFinished(second, result: Self.otherImage, url: Self.otherPage, imageUrl: "") == Self.otherImage)
    }

    @Test("Tokens keep increasing across finished lookups")
    func tokensIncreaseAcrossLookups() throws {
        var state = makeSUT()
        let firstStarted = state.urlEditingFinished(url: Self.page, imageUrl: "")
        let first = try #require(firstStarted)
        _ = state.lookupFinished(first, result: nil, url: Self.page, imageUrl: "")
        let secondStarted = state.urlEditingFinished(url: Self.otherPage, imageUrl: "")
        let second = try #require(secondStarted)
        #expect(second.token > first.token)
    }

    @Test("A result for a lookup that is not the current one is dropped and changes nothing")
    func staleResultDropped() throws {
        var state = makeSUT()
        let lookupStarted = state.urlEditingFinished(url: Self.page, imageUrl: "")
        let lookup = try #require(lookupStarted)
        let unknown = ItemImageLookup(token: lookup.token + 100, url: Self.page)
        let before = state
        #expect(state.lookupFinished(unknown, result: Self.image, url: Self.page, imageUrl: "") == nil)
        #expect(state == before)
    }

    // MARK: - Finishing

    @Test("A good result fills, sets source fetched and clears inFlight")
    func goodResultFills() throws {
        var state = makeSUT()
        let lookupStarted = state.urlEditingFinished(url: Self.page, imageUrl: "")
        let lookup = try #require(lookupStarted)
        #expect(state.lookupFinished(lookup, result: Self.image, url: "  \(Self.page) ", imageUrl: "") == Self.image)
        #expect(state.source == .fetched)
        #expect(state.inFlight == nil)
        #expect(!state.isLooking)
    }

    @Test("A nil result changes nothing but clears inFlight")
    func nilResultClearsInFlight() throws {
        var state = makeSUT()
        let lookupStarted = state.urlEditingFinished(url: Self.page, imageUrl: "")
        let lookup = try #require(lookupStarted)
        #expect(state.lookupFinished(lookup, result: nil, url: Self.page, imageUrl: "") == nil)
        #expect(state.source == .empty)
        #expect(state.inFlight == nil)
    }

    @Test("A result the filter rejects returns nil", arguments: [
        "http://images.example.test/a.jpg",
        "https://user:pw@images.example.test/a.jpg",
        "https://images.example.test/a b.jpg",
        "https://images.example.test/" + String(repeating: "a", count: 2048)
    ])
    func filteredResultReturnsNil(result: String) throws {
        var state = makeSUT()
        let lookupStarted = state.urlEditingFinished(url: Self.page, imageUrl: "")
        let lookup = try #require(lookupStarted)
        #expect(state.lookupFinished(lookup, result: result, url: Self.page, imageUrl: "") == nil)
        #expect(state.source == .empty)
        #expect(state.inFlight == nil)
    }

    @Test("A result for a url the field no longer holds is dropped")
    func resultForChangedUrlDropped() throws {
        var state = makeSUT()
        let lookupStarted = state.urlEditingFinished(url: Self.page, imageUrl: "")
        let lookup = try #require(lookupStarted)
        #expect(state.lookupFinished(lookup, result: Self.image, url: Self.otherPage, imageUrl: "") == nil)
        #expect(state.source == .empty)
        #expect(state.inFlight == nil)
    }

    @Test("When the user typed an image while the lookup ran, the result is dropped")
    func userTypedMeanwhile() throws {
        var state = makeSUT()
        let lookupStarted = state.urlEditingFinished(url: Self.page, imageUrl: "")
        let lookup = try #require(lookupStarted)
        state.imageTextChanged(to: "https://images.example.test/mine.jpg")
        #expect(state.lookupFinished(lookup, result: Self.image, url: Self.page,
                                     imageUrl: "https://images.example.test/mine.jpg") == nil)
        #expect(state.source == .typed)
    }

    @Test("On Edit, an image that is no longer blank drops the result")
    func editImageNoLongerBlank() throws {
        var state = makeSUT(mode: .edit(savedUrl: nil))
        let lookupStarted = state.urlEditingFinished(url: Self.page, imageUrl: "")
        let lookup = try #require(lookupStarted)
        #expect(state.lookupFinished(lookup, result: Self.image, url: Self.page, imageUrl: "x") == nil)
        #expect(state.source != .fetched)
        #expect(state.inFlight == nil)
    }

    @Test("cancel() forgets the in-flight lookup so its result is dropped")
    func cancelDropsResult() throws {
        var state = makeSUT()
        let lookupStarted = state.urlEditingFinished(url: Self.page, imageUrl: "")
        let lookup = try #require(lookupStarted)
        state.cancel()
        #expect(state.inFlight == nil)
        #expect(!state.isLooking)
        #expect(state.lookupFinished(lookup, result: Self.image, url: Self.page, imageUrl: "") == nil)
        #expect(state.source == .empty)
    }

    // MARK: - imageTextChanged

    @Test("The echo of the filled value keeps source fetched")
    func fillEchoKeepsFetched() throws {
        var state = makeSUT()
        let filled = try fill(&state)
        state.imageTextChanged(to: filled)
        #expect(state.source == .fetched)
    }

    @Test("Other text makes source typed and empty text makes it empty")
    func textChangesSource() throws {
        var state = makeSUT()
        let filled = try fill(&state)
        state.imageTextChanged(to: filled + "x")
        #expect(state.source == .typed)
        state.imageTextChanged(to: "")
        #expect(state.source == .empty)
        state.imageTextChanged(to: "abc")
        #expect(state.source == .typed)
    }

    @Test("After clearing the image a NEW url fills again")
    func clearThenNewUrlFills() throws {
        var state = makeSUT()
        try fill(&state)
        state.imageTextChanged(to: "")
        #expect(state.source == .empty)
        let lookup = state.urlEditingFinished(url: Self.otherPage, imageUrl: "")
        #expect(lookup?.url == Self.otherPage)
    }

    @Test("After clearing the image the SAME url does not call")
    func clearThenSameUrlNoCall() throws {
        var state = makeSUT()
        try fill(&state)
        state.imageTextChanged(to: "")
        #expect(state.urlEditingFinished(url: Self.page, imageUrl: "") == nil)
    }
}
