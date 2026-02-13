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
    private let pingInterval: TimeInterval = 5 * 60 // 5 minutes
    private let maxSessionDuration: TimeInterval = 24 * 60 * 60 // 24 hours
    
    // MARK: - Properties
    
    private let authRepository: AuthenticationRepository
    private var sessionStartTime: Date?
    private var lastActivityTime: Date?
    private var pingTask: Task<Void, Never>?
    
    // MARK: - Initialization
    
    init(authRepository: AuthenticationRepository) {
        self.authRepository = authRepository
    }
    
    // MARK: - Session Management
    
    /// Start session keep-alive
    func startSession() {
        sessionStartTime = Date()
        lastActivityTime = Date()
        
        // Start periodic ping
        pingTask = Task.detached(priority: .utility) { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(self?.pingInterval ?? 300))
                await self?.performPing()
            }
        }
        LogInfo("Session started with keep-alive", category: .auth)
    }
    
    /// Stop session keep-alive
    func stopSession() {
        pingTask?.cancel()
        pingTask = nil
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
    
    // MARK: - Private Helpers
    private func performPing() async {
        do {
            try await authRepository.ping()
            LogDebug("Session ping successful", category: .auth)
        } catch {
            LogError("Session ping failed: \(error)", category: .auth)
        }
    }
}
