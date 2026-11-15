//
//  ItemImageFillState.swift
//  ChristmasTracker
//
//  IMG1-P3: the pure decision table of the link-preview image fill (decisions 1 to 5). It decides
//  when a lookup starts, orders lookups with tokens, and decides whether a finished lookup may fill
//  the image field. No SwiftUI, no logging; page and image values are never stored beyond the
//  last page URL needed to avoid a repeat call.
//

import Foundation

/// Where the current image text came from.
nonisolated enum ItemImageSource: Equatable, Sendable {
    case empty
    case fetched
    case typed
}

/// Which form the fill belongs to. On Edit, `savedUrl` is the stored product URL (nil when none).
nonisolated enum ItemFormMode: Equatable, Sendable {
    case add
    case edit(savedUrl: String?)
}

/// One accepted lookup. A larger token is a later lookup.
nonisolated struct ItemImageLookup: Equatable, Sendable {
    let token: Int
    let url: String
    /// True for the lookup the user asked for with "Add image" (IMG1-P5).
    var isExplicit = false
}

/// The state of the explicit "Add image" action. `running` is derived from the in-flight lookup.
nonisolated enum ItemAddImageStatus: Equatable, Sendable {
    case idle
    case running
    case failed
}

nonisolated struct ItemImageFillState: Equatable, Sendable {
    let mode: ItemFormMode
    private(set) var source: ItemImageSource
    private(set) var inFlight: ItemImageLookup?
    private var lastToken = 0
    /// The page URL of the most recent accepted lookup; the same URL never calls twice in a row.
    private var lastLookedUpUrl: String?
    /// The last value this state handed out as a fill, to recognise its echo from the text field.
    private var lastFilled: String?
    /// Set when an explicit lookup ended without a usable image; cleared by the next action.
    private var addImageFailed = false

    var addImageStatus: ItemAddImageStatus {
        if inFlight?.isExplicit == true { return .running }
        return addImageFailed ? .failed : .idle
    }

    var isLooking: Bool { inFlight != nil }

    init(mode: ItemFormMode, initialImageUrl: String = "") {
        self.mode = mode
        self.source = Self.isBlank(initialImageUrl) ? .empty : .typed
    }

    // MARK: - Start

    /// A lookup to run for the finished URL field, or nil when no call is due. Invalid URLs change
    /// nothing.
    mutating func urlEditingFinished(url: String, imageUrl: String) -> ItemImageLookup? {
        guard let page = LinkPreviewInput.validated(Self.trimmed(url)) else { return nil }
        guard mayFill(imageUrl: imageUrl) else { return nil }
        if case .edit(let savedUrl) = mode, Self.trimmed(savedUrl ?? "") == page { return nil }
        guard page != lastLookedUpUrl else { return nil }

        lastToken += 1
        let lookup = ItemImageLookup(token: lastToken, url: page)
        inFlight = lookup
        lastLookedUpUrl = page
        addImageFailed = false
        return lookup
    }

    // MARK: - Add image (explicit)

    /// Edit only, a blank image text and a valid page URL. Stays true while the lookup runs and
    /// after a failure.
    func addImageVisible(url: String, imageUrl: String) -> Bool {
        guard case .edit = mode, Self.isBlank(imageUrl) else { return false }
        return LinkPreviewInput.validated(Self.trimmed(url)) != nil
    }

    /// Visible and no lookup in flight.
    func addImageEnabled(url: String, imageUrl: String) -> Bool {
        addImageVisible(url: url, imageUrl: imageUrl) && inFlight == nil
    }

    /// A tap on "Add image": an explicit lookup even when the URL equals the saved one, or nil.
    mutating func addImageRequested(url: String, imageUrl: String) -> ItemImageLookup? {
        guard addImageEnabled(url: url, imageUrl: imageUrl),
              let page = LinkPreviewInput.validated(Self.trimmed(url)) else { return nil }

        lastToken += 1
        let lookup = ItemImageLookup(token: lastToken, url: page, isExplicit: true)
        inFlight = lookup
        lastLookedUpUrl = page
        addImageFailed = false
        return lookup
    }

    // MARK: - Finish

    /// The image to put in the field, or nil. `url` and `imageUrl` are the live field values now.
    /// A stale lookup changes nothing; any other finish clears `inFlight`.
    mutating func lookupFinished(_ lookup: ItemImageLookup, result: String?, url: String, imageUrl: String) -> String? {
        guard lookup == inFlight else { return nil }
        inFlight = nil
        guard Self.trimmed(url) == lookup.url, mayFill(imageUrl: imageUrl) else { return nil }
        guard let accepted = LinkPreviewImageFilter.accepted(result) else {
            if lookup.isExplicit { addImageFailed = true }
            return nil
        }
        source = .fetched
        lastFilled = accepted
        return accepted
    }

    /// Forgets the in-flight lookup so its result is dropped.
    mutating func cancel() {
        inFlight = nil
        addImageFailed = false
    }

    // MARK: - Image text

    /// Called for every change of the image field text.
    mutating func imageTextChanged(to text: String) {
        if !(source == .fetched && text == lastFilled) { addImageFailed = false }
        if Self.isBlank(text) {
            source = .empty
        } else if source == .fetched, text == lastFilled {
            return
        } else {
            source = .typed
        }
    }

    // MARK: - Helpers

    /// Add: empty or previously fetched. Edit: only a blank image field.
    private func mayFill(imageUrl: String) -> Bool {
        switch mode {
        case .add: source != .typed
        case .edit: Self.isBlank(imageUrl) && source != .typed
        }
    }

    private static func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func isBlank(_ text: String) -> Bool {
        trimmed(text).isEmpty
    }
}
