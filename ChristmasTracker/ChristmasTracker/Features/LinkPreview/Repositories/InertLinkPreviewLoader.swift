//
//  InertLinkPreviewLoader.swift
//  ChristmasTracker
//
//  The loader of the failed-bootstrap dependencies and of the environment default: it contacts
//  nothing and always finds no image.
//

import Foundation

nonisolated final class InertLinkPreviewLoader: LinkPreviewLoading, Sendable {

    init() {}

    // Intentionally uninstrumented: an inert stub that does no work and no I/O.
    func imageUrl(for pageURL: String) async throws -> String? {
        nil
    }
}
