//
//  ProductImageURLNormalizer.swift
//  ChristmasTracker
//
//  Decision 13: a device-found image value is upgraded from http to https (same host, path and query),
//  then must pass LinkPreviewImageFilter (https, host, at most 2048 after the upgrade, no whitespace
//  or control characters, no userinfo). Anything else, nil and empty included, is nil. The value is
//  never logged.
//

import Foundation

nonisolated enum ProductImageURLNormalizer {

    private static let httpPrefix = "http://"

    static func normalized(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        let upgraded = value.hasPrefix(httpPrefix) ? "https://" + value.dropFirst(httpPrefix.count) : value
        return LinkPreviewImageFilter.accepted(upgraded)
    }
}
