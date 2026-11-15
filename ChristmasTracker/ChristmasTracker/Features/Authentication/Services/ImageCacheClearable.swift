//
//  ImageCacheClearable.swift
//  ChristmasTracker
//
//  Story TH1-T6: clears the shared URL cache (which holds thumbnail responses) at session end.
//

import Foundation
import Sentry

/// The seam over the image cache so the clear is testable.
nonisolated protocol ImageCacheClearing: Sendable {
    func removeAllCachedResponses()
}

nonisolated struct URLCacheClearer: ImageCacheClearing {
    func removeAllCachedResponses() {
        URLCache.shared.removeAllCachedResponses()
    }
}

final class ImageCacheClearable: SessionClearable {
    private let cache: any ImageCacheClearing

    init(cache: any ImageCacheClearing) {
        self.cache = cache
    }

    // Actor-isolated (@MainActor): @Instrumented cannot be applied to this @MainActor method,
    // so a manual span is used. No data goes into the span.
    func clearForSession() async throws {
        let span = SentrySDK.startTransaction(
            name: "service.imageCache.clearForSession",
            operation: "service.imageCache.clearForSession"
        )
        defer { span.finish() }

        cache.removeAllCachedResponses()
    }
}
