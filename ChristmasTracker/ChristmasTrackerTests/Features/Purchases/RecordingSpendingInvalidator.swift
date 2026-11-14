//
//  RecordingSpendingInvalidator.swift
//  ChristmasTrackerTests
//
//  I5a Story B: a fake SpendingCacheInvalidating that counts how often the runner (or anything else)
//  asked for the spending caches to be marked stale, and lets a test snapshot the world at the moment
//  of the call (for the ordering test). MainActor like the protocol requirement.
//

import Foundation
@testable import ChristmasTracker

@MainActor
final class RecordingSpendingInvalidator: SpendingCacheInvalidating {

    private(set) var markCount = 0

    /// Called inside markSpendingStale, before the count is returned to the test.
    var onMark: (@MainActor () -> Void)?

    func markSpendingStale() {
        markCount += 1
        onMark?()
    }
}
