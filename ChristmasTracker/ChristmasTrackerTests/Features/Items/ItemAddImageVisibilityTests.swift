//
//  ItemAddImageVisibilityTests.swift
//  ChristmasTrackerTests
//
//  IMG1-P5 (decision 16): when the explicit "Add image" button is shown and when it is enabled.
//  Shown on Edit only, only for a blank image text and a valid (trimmed) page url; it stays shown
//  while its own lookup runs and after a failure; it is enabled only while no lookup is in flight.
//
//  Covers ItemImageFillState.addImageVisible, addImageEnabled, addImageStatus and ItemAddImageStatus.
//

import Testing
import Foundation
@testable import ChristmasTracker

@Suite("Item add image visibility Tests")
struct ItemAddImageVisibilityTests {

    private static let page = "https://shop.example.test/p/1"
    private static let oldPage = "https://shop.example.test/old"
    private static let image = "https://images.example.test/a.jpg"

    // MARK: - Factory

    private func makeSUT(mode: ItemFormMode = .edit(savedUrl: page), initialImageUrl: String = "") -> ItemImageFillState {
        ItemImageFillState(mode: mode, initialImageUrl: initialImageUrl)
    }

    private static func longUrl(length: Int) -> String {
        let prefix = "https://shop.example.test/"
        return prefix + String(repeating: "a", count: length - prefix.count)
    }

    // MARK: - Visibility

    @Test("Edit, blank image, valid url: shown and enabled")
    func shownForBlankImageAndValidUrl() {
        let state = makeSUT()
        #expect(state.addImageVisible(url: Self.page, imageUrl: ""))
        #expect(state.addImageEnabled(url: Self.page, imageUrl: ""))
        #expect(state.addImageStatus == .idle)
    }

    @Test("A blank image after trimming counts as blank", arguments: ["", "   ", "\n", " \t "])
    func blankImageVariants(image: String) {
        #expect(makeSUT().addImageVisible(url: Self.page, imageUrl: image))
    }

    @Test("A padded valid url is shown")
    func paddedUrlShown() {
        #expect(makeSUT().addImageVisible(url: "  \(Self.page)  ", imageUrl: ""))
    }

    @Test("Edit with a stored image is hidden")
    func storedImageHidden() {
        let stored = "https://images.example.test/stored.jpg"
        let state = makeSUT(initialImageUrl: stored)
        #expect(!state.addImageVisible(url: Self.page, imageUrl: stored))
        #expect(!state.addImageEnabled(url: Self.page, imageUrl: stored))
    }

    @Test("Edit with a typed image is hidden")
    func typedImageHidden() {
        var state = makeSUT()
        state.imageTextChanged(to: "h")
        #expect(!state.addImageVisible(url: Self.page, imageUrl: "h"))
    }

    @Test("Edit with a fetched image is hidden")
    func fetchedImageHidden() throws {
        var state = makeSUT(mode: .edit(savedUrl: Self.oldPage))
        let started = state.urlEditingFinished(url: Self.page, imageUrl: "")
        let lookup = try #require(started)
        let filled = state.lookupFinished(lookup, result: Self.image, url: Self.page, imageUrl: "")
        #expect(filled == Self.image)
        #expect(!state.addImageVisible(url: Self.page, imageUrl: Self.image))
    }

    @Test("Hidden for an invalid url", arguments: [
        "",
        "   ",
        "ftp://shop.example.test/p",
        "https://user:secret@shop.example.test/p",
        "https://shop.example.test/a b",
        "https:///path-only",
        "not a url"
    ])
    func invalidUrlHidden(url: String) {
        let state = makeSUT()
        #expect(!state.addImageVisible(url: url, imageUrl: ""))
        #expect(!state.addImageEnabled(url: url, imageUrl: ""))
    }

    @Test("Hidden for a url over 2048 characters, shown at exactly 2048")
    func urlLengthBoundary() {
        let state = makeSUT()
        #expect(state.addImageVisible(url: Self.longUrl(length: 2048), imageUrl: ""))
        #expect(!state.addImageVisible(url: Self.longUrl(length: 2049), imageUrl: ""))
    }

    @Test("Add mode never shows it, even with a blank image and a valid url", arguments: ["", "  "])
    func addModeNeverShows(image: String) {
        let state = makeSUT(mode: .add)
        #expect(!state.addImageVisible(url: Self.page, imageUrl: image))
        #expect(!state.addImageEnabled(url: Self.page, imageUrl: image))
    }

    // MARK: - While running, after failure, after the fill

    @Test("Shown but not enabled while its own lookup runs")
    func shownWhileRunning() throws {
        var state = makeSUT()
        let r1 = state.addImageRequested(url: Self.page, imageUrl: "")
        _ = try #require(r1)
        #expect(state.addImageStatus == .running)
        #expect(state.addImageVisible(url: Self.page, imageUrl: ""))
        #expect(!state.addImageEnabled(url: Self.page, imageUrl: ""))
    }

    @Test("Shown and enabled again after a failure so the user can retry")
    func shownAndEnabledAfterFailure() throws {
        var state = makeSUT()
        let r2 = state.addImageRequested(url: Self.page, imageUrl: "")
        let lookup = try #require(r2)
        _ = state.lookupFinished(lookup, result: nil, url: Self.page, imageUrl: "")
        #expect(state.addImageStatus == .failed)
        #expect(state.addImageVisible(url: Self.page, imageUrl: ""))
        #expect(state.addImageEnabled(url: Self.page, imageUrl: ""))
    }

    @Test("Hidden once the fill landed")
    func hiddenAfterFill() throws {
        var state = makeSUT()
        let r3 = state.addImageRequested(url: Self.page, imageUrl: "")
        let lookup = try #require(r3)
        let filled = state.lookupFinished(lookup, result: Self.image, url: Self.page, imageUrl: "")
        #expect(filled == Self.image)
        #expect(!state.addImageVisible(url: Self.page, imageUrl: Self.image))
        #expect(state.addImageStatus == .idle)
    }

    // MARK: - Enabled

    @Test("Not enabled while an automatic lookup is in flight, but still shown")
    func disabledDuringAutomaticLookup() throws {
        var state = makeSUT(mode: .edit(savedUrl: Self.oldPage))
        let r4 = state.urlEditingFinished(url: Self.page, imageUrl: "")
        _ = try #require(r4)
        #expect(state.isLooking)
        #expect(state.addImageStatus == .idle)
        #expect(state.addImageVisible(url: Self.page, imageUrl: ""))
        #expect(!state.addImageEnabled(url: Self.page, imageUrl: ""))
    }

    @Test("Enabled again once the automatic lookup finished without an image")
    func enabledAfterAutomaticLookupEnds() throws {
        var state = makeSUT(mode: .edit(savedUrl: Self.oldPage))
        let r5 = state.urlEditingFinished(url: Self.page, imageUrl: "")
        let lookup = try #require(r5)
        _ = state.lookupFinished(lookup, result: nil, url: Self.page, imageUrl: "")
        #expect(state.addImageEnabled(url: Self.page, imageUrl: ""))
        #expect(state.addImageStatus == .idle)
    }
}
