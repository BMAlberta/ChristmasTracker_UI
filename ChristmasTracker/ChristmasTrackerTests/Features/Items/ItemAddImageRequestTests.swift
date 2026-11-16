//
//  ItemAddImageRequestTests.swift
//  ChristmasTrackerTests
//
//  IMG1-P5 (decisions 3, 4, 6, 16, 17): the tap on "Add image" and the handling of its result in the
//  pure state: which tap starts a lookup, how the explicit result fills or fails, which results are
//  dropped silently, what clears the failed status, and that the fill is sent by the normal Save.
//
//  Assumption: the explicit marker on ItemImageLookup is a Bool named `isExplicit`.
//
//  Covers ItemImageFillState.addImageRequested, lookupFinished (explicit), cancel, imageTextChanged,
//  urlEditingFinished and ItemFormValidation.makeUpdateInput.
//

import Testing
import Foundation
@testable import ChristmasTracker

@Suite("Item add image request Tests")
struct ItemAddImageRequestTests {

    private static let page = "https://shop.example.test/p/1"
    private static let otherPage = "https://shop.example.test/p/2"
    private static let image = "https://images.example.test/a.jpg"

    // MARK: - Factory

    /// The key case: an old item whose url equals the saved one and whose image is blank.
    private func makeSUT(mode: ItemFormMode = .edit(savedUrl: page), initialImageUrl: String = "") -> ItemImageFillState {
        ItemImageFillState(mode: mode, initialImageUrl: initialImageUrl)
    }

    private func request(_ state: inout ItemImageFillState, url: String = page) throws -> ItemImageLookup {
        let started = state.addImageRequested(url: url, imageUrl: "")
        return try #require(started)
    }

    // MARK: - Starting

    @Test("Edit with a url equal to the saved url and a blank image returns an explicit lookup")
    func savedUrlStillLooksUp() throws {
        var state = makeSUT()
        let lookup = try request(&state)
        #expect(lookup.url == Self.page)
        #expect(lookup.isExplicit)
        #expect(state.inFlight == lookup)
        #expect(state.isLooking)
        #expect(state.addImageStatus == .running)
    }

    @Test("A padded url is trimmed in the lookup")
    func urlIsTrimmed() throws {
        var state = makeSUT()
        let lookup = try request(&state, url: "  \(Self.page)\n")
        #expect(lookup.url == Self.page)
    }

    @Test("The automatic lookup is not explicit")
    func automaticLookupIsNotExplicit() throws {
        var state = makeSUT(mode: .edit(savedUrl: Self.otherPage))
        let started = state.urlEditingFinished(url: Self.page, imageUrl: "")
        let lookup = try #require(started)
        #expect(!lookup.isExplicit)
    }

    @Test("The memberwise initializer without the marker still compiles and is not explicit")
    func defaultedMarker() {
        let lookup = ItemImageLookup(token: 1, url: Self.page)
        #expect(!lookup.isExplicit)
    }

    @Test("Add mode returns nil and changes nothing")
    func addModeNil() {
        var state = makeSUT(mode: .add)
        let before = state
        let r1 = state.addImageRequested(url: Self.page, imageUrl: "")
        #expect(r1 == nil)
        #expect(state == before)
        #expect(state.addImageStatus == .idle)
    }

    @Test("Not visible returns nil and changes nothing", arguments: [
        ("", "https://images.example.test/stored.jpg"),
        ("https://shop.example.test/p/1", "https://images.example.test/stored.jpg"),
        ("ftp://shop.example.test/p", ""),
        ("", ""),
        ("https://user:pw@shop.example.test/p", "")
    ])
    func notVisibleNil(url: String, imageUrl: String) {
        var state = makeSUT()
        let before = state
        let r2 = state.addImageRequested(url: url, imageUrl: imageUrl)
        #expect(r2 == nil)
        #expect(state == before)
    }

    @Test("A second tap while running returns nil and changes nothing")
    func secondTapWhileRunning() throws {
        var state = makeSUT()
        _ = try request(&state)
        let before = state
        let r3 = state.addImageRequested(url: Self.page, imageUrl: "")
        #expect(r3 == nil)
        #expect(state == before)
    }

    @Test("A tap while an automatic lookup runs returns nil")
    func tapDuringAutomaticLookup() throws {
        var state = makeSUT(mode: .edit(savedUrl: Self.otherPage))
        let r4 = state.urlEditingFinished(url: Self.page, imageUrl: "")
        _ = try #require(r4)
        let r5 = state.addImageRequested(url: Self.page, imageUrl: "")
        #expect(r5 == nil)
        #expect(state.addImageStatus == .idle)
    }

    @Test("A blur after the tap does not repeat the call")
    func blurAfterTapDoesNotRepeat() throws {
        var state = makeSUT(mode: .edit(savedUrl: Self.otherPage))
        let lookup = try request(&state)
        _ = state.lookupFinished(lookup, result: nil, url: Self.page, imageUrl: "")
        let r6 = state.urlEditingFinished(url: Self.page, imageUrl: "")
        #expect(r6 == nil)
    }

    // MARK: - Results

    @Test("A valid value fills as a fetched value, returns it and ends idle")
    func valueFills() throws {
        var state = makeSUT()
        let lookup = try request(&state)
        let filled = state.lookupFinished(lookup, result: Self.image, url: Self.page, imageUrl: "")
        #expect(filled == Self.image)
        #expect(state.source == .fetched)
        #expect(state.addImageStatus == .idle)
        #expect(!state.isLooking)
    }

    @Test("A nil result sets failed and returns nil")
    func nilFails() throws {
        var state = makeSUT()
        let lookup = try request(&state)
        let filled = state.lookupFinished(lookup, result: nil, url: Self.page, imageUrl: "")
        #expect(filled == nil)
        #expect(state.addImageStatus == .failed)
        #expect(state.source == .empty)
        #expect(!state.isLooking)
    }

    @Test("A filtered-out value fails", arguments: [
        "http://images.example.test/a.jpg",
        "https://user:pw@images.example.test/a.jpg",
        "https://images.example.test/a b.jpg",
        "https://images.example.test/" + String(repeating: "a", count: 2048),
        "ftp://images.example.test/a.jpg",
        ""
    ])
    func filteredOutFails(value: String) throws {
        var state = makeSUT()
        let lookup = try request(&state)
        let filled = state.lookupFinished(lookup, result: value, url: Self.page, imageUrl: "")
        #expect(filled == nil)
        #expect(state.addImageStatus == .failed)
        #expect(state.source == .empty)
    }

    @Test("After a failure a second tap works")
    func retryAfterFailure() throws {
        var state = makeSUT()
        let first = try request(&state)
        _ = state.lookupFinished(first, result: nil, url: Self.page, imageUrl: "")
        let second = try request(&state)
        #expect(second.token > first.token)
        #expect(second.isExplicit)
        #expect(state.addImageStatus == .running)
    }

    @Test("A result of the retry fills and leaves no failure")
    func retryFills() throws {
        var state = makeSUT()
        let first = try request(&state)
        _ = state.lookupFinished(first, result: nil, url: Self.page, imageUrl: "")
        let second = try request(&state)
        let filled = state.lookupFinished(second, result: Self.image, url: Self.page, imageUrl: "")
        #expect(filled == Self.image)
        #expect(state.addImageStatus == .idle)
    }

    // MARK: - Dropped silently

    @Test("A stale lookup is dropped with no state change")
    func staleDropped() throws {
        var state = makeSUT()
        let old = try request(&state)
        state.cancel()
        let current = try request(&state)
        let before = state
        let filled = state.lookupFinished(old, result: Self.image, url: Self.page, imageUrl: "")
        #expect(filled == nil)
        #expect(state == before)
        #expect(state.addImageStatus == .running)
        #expect(state.inFlight == current)
    }

    @Test("A stale nil result does not show a failure")
    func staleNilNotFailure() throws {
        var state = makeSUT()
        let old = try request(&state)
        state.cancel()
        _ = state.lookupFinished(old, result: nil, url: Self.page, imageUrl: "")
        #expect(state.addImageStatus == .idle)
    }

    @Test("A result for a url the field no longer holds is dropped silently", arguments: ["https://images.example.test/a.jpg", nil as String?])
    func urlChangedMeanwhile(result: String?) throws {
        var state = makeSUT()
        let lookup = try request(&state)
        let filled = state.lookupFinished(lookup, result: result, url: Self.otherPage, imageUrl: "")
        #expect(filled == nil)
        #expect(state.addImageStatus == .idle)
        #expect(!state.isLooking)
        #expect(state.source == .empty)
    }

    @Test("A result after the user typed an image is dropped silently", arguments: ["https://images.example.test/a.jpg", nil as String?])
    func userTypedMeanwhile(result: String?) throws {
        var state = makeSUT()
        let lookup = try request(&state)
        state.imageTextChanged(to: "https://images.example.test/mine.jpg")
        let filled = state.lookupFinished(lookup, result: result, url: Self.page,
                                          imageUrl: "https://images.example.test/mine.jpg")
        #expect(filled == nil)
        #expect(state.addImageStatus == .idle)
        #expect(state.source == .typed)
    }

    @Test("A result when the live image text is no longer blank is dropped silently")
    func imageNoLongerBlank() throws {
        var state = makeSUT()
        let lookup = try request(&state)
        let filled = state.lookupFinished(lookup, result: nil, url: Self.page, imageUrl: "x")
        #expect(filled == nil)
        #expect(state.addImageStatus == .idle)
    }

    @Test("cancel() sets idle without a failure and drops the result")
    func cancelIsIdle() throws {
        var state = makeSUT()
        let lookup = try request(&state)
        state.cancel()
        #expect(state.addImageStatus == .idle)
        #expect(!state.isLooking)
        let filled = state.lookupFinished(lookup, result: Self.image, url: Self.page, imageUrl: "")
        #expect(filled == nil)
        #expect(state.addImageStatus == .idle)
    }

    @Test("An automatic lookup starting supersedes the explicit one; its result is dropped")
    func automaticSupersedesExplicit() throws {
        var state = makeSUT()
        let explicit = try request(&state)
        let started = state.urlEditingFinished(url: Self.otherPage, imageUrl: "")
        let automatic = try #require(started)
        #expect(!automatic.isExplicit)
        #expect(state.addImageStatus == .idle)
        #expect(state.inFlight == automatic)

        let dropped = state.lookupFinished(explicit, result: Self.image, url: Self.otherPage, imageUrl: "")
        #expect(dropped == nil)
        #expect(state.addImageStatus == .idle)
        #expect(state.inFlight == automatic)
    }

    // MARK: - Clearing failed

    private func failedState() throws -> ItemImageFillState {
        var state = makeSUT()
        let lookup = try request(&state)
        _ = state.lookupFinished(lookup, result: nil, url: Self.page, imageUrl: "")
        #expect(state.addImageStatus == .failed)
        return state
    }

    @Test("A typed character in the image text clears failed")
    func typingClearsFailed() throws {
        var state = try failedState()
        state.imageTextChanged(to: "h")
        #expect(state.addImageStatus == .idle)
    }

    @Test("A new automatic lookup starting clears failed")
    func automaticLookupClearsFailed() throws {
        var state = try failedState()
        let started = state.urlEditingFinished(url: Self.otherPage, imageUrl: "")
        #expect(started != nil)
        #expect(state.addImageStatus == .idle)
    }

    @Test("An automatic call that returns no lookup keeps failed")
    func noAutomaticLookupKeepsFailed() throws {
        var state = try failedState()
        let r7 = state.urlEditingFinished(url: "ftp://shop.example.test/p", imageUrl: "")
        #expect(r7 == nil)
        #expect(state.addImageStatus == .failed)
    }

    @Test("cancel() clears failed")
    func cancelClearsFailed() throws {
        var state = try failedState()
        state.cancel()
        #expect(state.addImageStatus == .idle)
    }

    @Test("A new tap clears failed")
    func newTapClearsFailed() throws {
        var state = try failedState()
        _ = try request(&state)
        #expect(state.addImageStatus == .running)
    }

    // MARK: - The fill is a fetched value, saved by the normal Save

    @Test("The echo of the fill keeps the fetched source")
    func echoKeepsFetched() throws {
        var state = makeSUT()
        let lookup = try request(&state)
        let r8 = state.lookupFinished(lookup, result: Self.image, url: Self.page, imageUrl: "")
        let filled = try #require(r8)
        state.imageTextChanged(to: filled)
        #expect(state.source == .fetched)
    }

    @Test("Editing the filled value afterwards marks it typed")
    func editingFilledValueIsTyped() throws {
        var state = makeSUT()
        let lookup = try request(&state)
        let r9 = state.lookupFinished(lookup, result: Self.image, url: Self.page, imageUrl: "")
        let filled = try #require(r9)
        state.imageTextChanged(to: filled + "x")
        #expect(state.source == .typed)
    }

    @Test("After the fill the normal Save sends the image url and not the unchanged url")
    func fillIsSentBySave() throws {
        var state = makeSUT()
        let lookup = try request(&state)
        let r10 = state.lookupFinished(lookup, result: Self.image, url: Self.page, imageUrl: "")
        let filled = try #require(r10)

        let original = ItemFixtures.item(name: "Fake Lamp", description: "A fake lamp", url: Self.page, imageUrl: nil,
                                         price: nil, quantity: 2, priority: 5)
        let input = ItemFormValidation.makeUpdateInput(
            original: original, name: "Fake Lamp", description: "A fake lamp",
            url: Self.page, imageUrl: filled, priceText: "", quantity: 2, priority: 5
        )
        #expect(input?.imageUrl == Self.image)
        #expect(input?.url == nil)
    }
}
