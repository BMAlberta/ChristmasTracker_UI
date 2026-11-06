// SessionManagerDeadCodeTests.swift
// ChristmasTrackerTests
//
// Story C2 — Group C: SessionManager dead code removal tests.
//
// After C2:
//   - SessionManager.init(initialClearables:) is the only init (authRepository: param removed)
//   - stopSession(), isSessionValid(), baseSessionDuration, maxSessionDuration,
//     pingInterval, sessionStartTime, lastActivityTime, pingTask, performPing(),
//     and authRepository are all removed.
//
// C1 (kept): register(_:), teardown(reason:), startSession(), recordActivity()

import Testing
import Foundation
@testable import ChristmasTracker

@Suite("SessionManager dead code — C2")
struct SessionManagerDeadCodeTests {

    // MARK: - C1: init(initialClearables:) compiles without authRepository:

    @Test("SessionManager can be constructed with only initialClearables parameter")
    func sessionManagerInitWithOnlyInitialClearablesCompiles() async {
        // If authRepository: has been removed from init, this compiles and runs fine.
        // If authRepository: is still required, the build fails here (compile-time test).
        let manager = SessionManager(initialClearables: [])
        // Verify the manager is functional by calling a known surviving method.
        await manager.startSession()
        // No assertion needed — if this compiles and executes, the test passes.
    }

    // MARK: - C2: register(_:SessionClearable) exists

    @Test("SessionManager.register(_:) can be called with a SessionClearable")
    func sessionManagerRegisterClearableCompiles() async {
        let manager = SessionManager(initialClearables: [])
        let clearable = StubSessionClearable()
        await manager.register(clearable)
        // Verify clearForSession is called during teardown (proves register works)
        await manager.teardown(reason: .userLogout)
        #expect(clearable.clearCallCount == 1)
    }

    // MARK: - C3: teardown(reason:) exists

    @Test("SessionManager.teardown(reason:) exists and completes without throwing")
    func sessionManagerTeardownExists() async {
        let manager = SessionManager(initialClearables: [])
        await manager.teardown(reason: .userLogout)
        // If this compiles and runs, teardown(reason:) exists.
    }

    // MARK: - C4: startSession() exists

    @Test("SessionManager.startSession() exists and can be called")
    func sessionManagerStartSessionExists() async {
        let manager = SessionManager(initialClearables: [])
        await manager.startSession()
        // If this compiles and runs, startSession() exists.
    }

    // MARK: - C5: recordActivity() exists

    @Test("SessionManager.recordActivity() exists and can be called")
    func sessionManagerRecordActivityExists() async {
        let manager = SessionManager(initialClearables: [])
        await manager.startSession()
        await manager.recordActivity()
        // If this compiles and runs, recordActivity() exists.
    }
}

// MARK: - Stub SessionClearable

/// Minimal stub used only by Group C tests to verify register(_:) wiring.
private final class StubSessionClearable: SessionClearable, @unchecked Sendable {
    private let lock = NSLock()
    private var _clearCallCount = 0

    var clearCallCount: Int {
        lock.lock(); defer { lock.unlock() }
        return _clearCallCount
    }

    func clearForSession() async throws {
        lock.lock(); defer { lock.unlock() }
        _clearCallCount += 1
    }
}
