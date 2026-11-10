//
//  RepositoryCallLog.swift
//  ChristmasTrackerTests
//
//  Story I3b-M2: one ordered log shared by the gated list and member fakes, so a test can assert
//  the ORDER of calls across two repositories (for example add member, then refetch detail).
//  Entries are constant words plus fake ids.
//

import Foundation

@MainActor
final class RepositoryCallLog {
    private(set) var events: [String] = []

    func record(_ event: String) {
        events.append(event)
    }
}
