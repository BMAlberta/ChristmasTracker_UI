//
//  MockSessionClearable.swift
//  ChristmasTrackerTests
//

import Foundation
@testable import ChristmasTracker

/// Spy that records whether `clearForSession()` was called.
/// Can be configured to throw on the next call.
final class MockSessionClearable: SessionClearable, @unchecked Sendable {

    // MARK: - Spy State

    private let lock = NSLock()
    private var _clearCallCount: Int = 0
    private var _shouldThrow: Bool = false

    var clearCallCount: Int {
        lock.lock(); defer { lock.unlock() }
        return _clearCallCount
    }

    var wasClearCalled: Bool { clearCallCount > 0 }

    // MARK: - Configuration

    /// Set to true before calling teardown to simulate a failing clearable.
    func configureToThrow(_ throws: Bool = true) {
        lock.lock(); defer { lock.unlock() }
        _shouldThrow = `throws`
    }

    // MARK: - SessionClearable

    func clearForSession() async throws {
        lock.lock()
        let shouldThrow = _shouldThrow
        _clearCallCount += 1
        lock.unlock()

        if shouldThrow {
            throw MockSessionClearableError.simulatedFailure
        }
    }
}

enum MockSessionClearableError: Error {
    case simulatedFailure
}
