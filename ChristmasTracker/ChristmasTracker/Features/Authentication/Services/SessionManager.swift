//
//  SessionManager.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/9/26.
//

import Foundation

actor SessionManager {

    // MARK: - Properties

    private var clearables: [any SessionClearable] = []
    private(set) var lastTeardownReason: TeardownReason?

    // MARK: - Initialization

    init(initialClearables: [any SessionClearable] = []) {
        self.clearables = initialClearables
    }

    // MARK: - Clearable Registration

    /// Register a clearable store or service for teardown.
    func register(_ clearable: any SessionClearable) {
        clearables.append(clearable)
    }

    /// Tear down the session: clear all registered clearables,
    /// and flush system-level caches.  A failure in one clearable never stops others.
    // Actor-isolated: manual instrumentation only — @Instrumented not yet available (I6a)
    func teardown(reason: TeardownReason) async {
        self.lastTeardownReason = reason

        // Clear all clearables — never abort early, collect failures
        for clearable in clearables {
            do {
                try await clearable.clearForSession()
            } catch {
                LogError("Teardown clearable failed: \(error.localizedDescription)", category: .auth)
            }
        }

        // Clear system caches (URLCache, cookies) — user-scoped precaution
        URLCache.shared.removeAllCachedResponses()
        if let cookies = HTTPCookieStorage.shared.cookies {
            for cookie in cookies { HTTPCookieStorage.shared.deleteCookie(cookie) }
        }

        LogInfo("Session torn down — reason: \(reason)", category: .auth)
    }

    // MARK: - Session Management

    /// Start session keep-alive
    func startSession() {
        LogInfo("Session started", category: .auth)
    }

    /// Record user activity (no-op; retained for callers in AuthenticationService)
    func recordActivity() {
        // No-op: session timing removed in C2 dead-code cleanup.
    }
}
