//
//  LinkPresentationProductImageProvider.swift
//  ChristmasTracker
//
//  The on-device image lookup: LPMetadataProvider fetches the page metadata and the image URL string is
//  read from it. This is the ONLY file that imports LinkPresentation or reads the metadata key paths.
//  Neither the page URL nor the image value nor any error text is logged, reported or put in a span.
//
//  APPSTORE-BLOCKER: non-public key path. LPLinkMetadata has no public accessor for the image URL, so
//  it is read through the imageMetadata key path. Before App Store submission remove or replace this
//  key path (for example with the public imageProvider route).
//

import Foundation
import LinkPresentation
import Synchronization
import TrackerInstrumentation

// MARK: - Metadata reader

/// Pure, guarded two-hop extraction. Every hop checks responds(to:) first, so a missing selector, a nil
/// value or a value of the wrong type is nil and never raises an Objective-C exception.
nonisolated enum ProductImageMetadataReader {

    static func imageURLString(from metadata: NSObject) -> String? {
        guard metadata.responds(to: NSSelectorFromString("imageMetadata")) else { return nil }
        guard let imageMetadata = metadata.value(forKey: "imageMetadata") as? NSObject else { return nil }

        guard imageMetadata.responds(to: NSSelectorFromString("URL")) else { return nil }
        guard let url = imageMetadata.value(forKey: "URL") as? URL else { return nil }

        return url.absoluteString
    }
}

// MARK: - Provider

nonisolated final class LinkPresentationProductImageProvider: ProductImageProviding, Sendable {

    /// Seconds before the metadata fetch gives up.
    static let timeout: TimeInterval = 8

    init() {}

    @Instrumented
    func imageUrl(for pageURL: String) async throws -> String? {
        guard let url = URL(string: pageURL) else { return nil }
        let fetch = MetadataFetch()
        return try await withTaskCancellationHandler {
            try await fetch.run(url)
        } onCancel: {
            fetch.cancel()
        }
    }
}

// MARK: - One fetch

/// One metadata fetch. The non-Sendable LPMetadataProvider lives behind a Mutex, and the continuation
/// is taken out of its box exactly once, so a second completion can never resume it again.
private nonisolated final class MetadataFetch: Sendable {

    private let lp = Mutex(LPMetadataProvider())
    private let continuation = Mutex<CheckedContinuation<String?, any Error>?>(nil)
    private let cancelled = Mutex(false)

    // Private helper covered by the @Instrumented imageUrl(for:), which is its only caller.
    func run(_ url: URL) async throws -> String? {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<String?, any Error>) in
            continuation.withLock { $0 = cont }
            lp.withLock { provider in
                // A cancel that arrived before the fetch started finds the flag here.
                if cancelled.withLock({ $0 }) {
                    finish(value: nil, error: CancellationError())
                    return
                }
                provider.timeout = LinkPresentationProductImageProvider.timeout
                provider.startFetchingMetadata(for: url) { [self] metadata, error in
                    // LPLinkMetadata is not Sendable: only a String? leaves this closure.
                    let value = metadata.flatMap { ProductImageMetadataReader.imageURLString(from: $0) }
                    finish(value: value, error: error)
                }
            }
        }
    }

    /// Cancels the LPMetadataProvider; its completion then ends the pending call.
    func cancel() {
        cancelled.withLock { $0 = true }
        lp.withLock { $0.cancel() }
    }

    /// Resumes the pending call exactly once; any later call finds the box empty and does nothing.
    private func finish(value: String?, error: (any Error)?) {
        guard let cont = continuation.withLock({ box in
            let taken = box
            box = nil
            return taken
        }) else { return }

        if error is CancellationError || cancelled.withLock({ $0 }) {
            cont.resume(throwing: CancellationError())
        } else {
            // Any other fetch error, a timeout included, is simply no image.
            cont.resume(returning: error == nil ? value : nil)
        }
    }
}
