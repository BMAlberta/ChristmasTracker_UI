//
//  LinkPreviewLoading.swift
//  ChristmasTracker
//
//  The seam for the product image of a page URL. Implementations return the image URL or nil, and
//  throw only `CancellationError`: every other failure is nil ("no image"). Neither the page URL nor
//  the image URL is ever logged or put in an error.
//

import Foundation

nonisolated protocol LinkPreviewLoading: Sendable {
    func imageUrl(for pageURL: String) async throws -> String?
}
