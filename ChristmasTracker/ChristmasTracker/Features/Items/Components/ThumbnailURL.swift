//
//  ThumbnailURL.swift
//  ChristmasTracker
//
//  Story TH1-T6: the pure rule for which item image values may be loaded. The value is never
//  logged or reported anywhere; the thumbnail is decorative.
//

import Foundation
import CoreGraphics
import SwiftUI

/// Validates an item's image value. Only an absolute https URL with a host, no whitespace or
/// control characters, and at most `maximumLength` characters is accepted.
nonisolated enum ThumbnailURL {
    static let maximumLength = 2048

    static func validate(_ value: String?) -> URL? {
        guard let value, !value.isEmpty, value.count <= maximumLength else { return nil }
        let forbidden = CharacterSet.whitespacesAndNewlines.union(.controlCharacters)
        guard value.rangeOfCharacter(from: forbidden) == nil else { return nil }
        guard let components = URLComponents(string: value),
              components.scheme?.lowercased() == "https",
              let host = components.host, !host.isEmpty,
              let url = components.url, url.absoluteString == value,
              url.host()?.isEmpty == false
        else { return nil }
        return url
    }
}

/// What a thumbnail shows.
nonisolated enum ThumbnailContent: Equatable, Sendable {
    case image(URL)
    case placeholder
}

nonisolated enum ThumbnailPresentation {
    /// An invalid or missing value is the placeholder; a failed load is shown the same way.
    static func content(for value: String?) -> ThumbnailContent {
        ThumbnailURL.validate(value).map(ThumbnailContent.image) ?? .placeholder
    }
}

nonisolated enum ThumbnailLayout {
    static let baseSize: CGFloat = 56
    /// The scaled size never grows past twice the base.
    static let maximumSize: CGFloat = 112

    static func clamped(_ scaled: CGFloat) -> CGFloat {
        min(scaled, maximumSize)
    }

    /// The row drops its thumbnail at accessibility sizes so the text keeps the width.
    static func rowThumbnailVisible(for size: DynamicTypeSize) -> Bool {
        !size.isAccessibilitySize
    }
}
