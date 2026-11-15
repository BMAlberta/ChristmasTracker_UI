//
//  InertProductImageProvider.swift
//  ChristmasTracker
//
//  The provider of the failed-bootstrap dependencies and of the service default: it contacts nothing
//  and always finds no image.
//

import Foundation

nonisolated final class InertProductImageProvider: ProductImageProviding, Sendable {

    init() {}

    // Intentionally uninstrumented: an inert stub that does no work and no I/O.
    func imageUrl(for pageURL: String) async throws -> String? {
        nil
    }
}
