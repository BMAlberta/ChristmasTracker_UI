//
//  MockProductImageProvider.swift
//  ChristmasTracker
//
//  Mock-mode provider: a fixed https image for pages on its known host (http or https), nil for
//  everything else. No network.
//

import Foundation

nonisolated final class MockProductImageProvider: ProductImageProviding, Sendable {

    static let knownHost = "device.example.test"
    static let fixedImageUrl = "https://images.example.test/device.jpg"

    init() {}

    // Intentionally uninstrumented: a mock that does no work and no I/O.
    func imageUrl(for pageURL: String) async throws -> String? {
        guard let components = URLComponents(string: pageURL),
              let scheme = components.scheme?.lowercased(), scheme == "http" || scheme == "https",
              components.host?.lowercased() == Self.knownHost
        else { return nil }
        return Self.fixedImageUrl
    }
}
