//
//  MockLinkPreviewRepository.swift
//  ChristmasTracker
//
//  Deterministic link preview for mock mode and previews: a page on `knownHost` (exact host match
//  only) gets `fixedImageUrl`; everything else gets nil. No network. Intentionally uninstrumented
//  (a mock).
//

import Foundation

nonisolated final class MockLinkPreviewRepository: LinkPreviewLoading, Sendable {

    static let knownHost = "shop.example.test"
    static let fixedImageUrl = "https://images.example.test/preview.jpg"

    init() {}

    func imageUrl(for pageURL: String) async throws -> String? {
        guard let host = URLComponents(string: pageURL)?.host else { return nil }
        return host == Self.knownHost ? Self.fixedImageUrl : nil
    }
}
