//
//  SessionManager.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/9/26.
//

import Foundation

actor SessionManager {
    
    // MARK: - Configuration
    private let baseSessionDuration: TimeInterval = 30 * 60 // 30 minutes
    private let maxSessionDuration: TimeInterval = 24 * 60 * 60 // 24 hours

    // MARK: - Properties

    private let authRepository: AuthenticationRepository
    private var sessionStartTime: Date?
    private var lastActivityTime: Date?
    private var clearables: [any SessionClearable] = []
    private(set) var lastTeardownReason: TeardownReason?

    // MARK: - Initialization
    
    init(authRepository: AuthenticationRepository,
         initialClearables: [any SessionClearable] = []) {
        self.authRepository = authRepository
        self.clearables = initialClearables
    }
    
    // MARK: - Clearable Registration

    /// Register a clearable store or service for teardown.
    func register(_ clearable: any SessionClearable) {
        clearables.append(clearable)
    }

    /// Tear down the session: cancel pings, clear all registered clearables,
    /// and flush system-level caches.  A failure in one clearable never stops others.
    // Actor-isolated: manual instrumentation only — @Instrumented not yet available (I6a)
    func teardown(reason: TeardownReason) async {
        self.lastTeardownReason = reason
        sessionStartTime = nil
        lastActivityTime = nil

        // 2. Clear all clearables — never abort early, collect failures
        for clearable in clearables {
            do {
                try await clearable.clearForSession()
            } catch {
                LogError("Teardown clearable failed: \(error.localizedDescription)", category: .auth)
            }
        }

        // 3. Clear system caches (URLCache, cookies) — user-scoped precaution
        URLCache.shared.removeAllCachedResponses()
        if let cookies = HTTPCookieStorage.shared.cookies {
            for cookie in cookies { HTTPCookieStorage.shared.deleteCookie(cookie) }
        }

        LogInfo("Session torn down — reason: \(reason)", category: .auth)
    }

    // MARK: - Session Management

    /// Start session keep-alive
    func startSession() {
        sessionStartTime = Date()
        lastActivityTime = Date()
        LogInfo("Session started", category: .auth)
    }

    /// Stop session keep-alive
    func stopSession() {
        sessionStartTime = nil
        lastActivityTime = nil
    }
    
    /// Record user activity
    func recordActivity() {
        lastActivityTime = Date()
    }
    
    /// Check if session is still valid
    func isSessionValid() -> Bool {
        guard let sessionStartTime = sessionStartTime,
                let lastActivityTime = lastActivityTime else {
            return false
        }
        
        let now = Date()
        
        if now.timeIntervalSince(sessionStartTime) > maxSessionDuration {
            LogWarning("Session exceeded max duration (24h)", category: .auth)
            return false
        }
        
        if now.timeIntervalSince(lastActivityTime) > baseSessionDuration {
            LogWarning("Session expired due to no activity", category: .auth)
            return false
        }
        return true
    }
    
}
