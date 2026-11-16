//
//  ProductImageProviding.swift
//  ChristmasTracker
//
//  The on-device step of the product image lookup: given a page URL, find an image URL string on the
//  device. It throws only CancellationError; every other failure is nil. The caller validates and
//  normalizes the returned value. Neither the page URL nor the value is ever logged.
//

import Foundation

nonisolated protocol ProductImageProviding: Sendable {
    func imageUrl(for pageURL: String) async throws -> String?
}
