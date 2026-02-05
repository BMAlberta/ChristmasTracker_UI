//
//  AppConfiguration.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/3/26.
//

import Foundation

/// Global application configuration loaded from xcconfig
struct AppConfiguration {
    // MARK: - API Configuration
    /// API base URL loaded from xcconfig
    /// Production: https://api.christmastracker.com
    /// QA: https://api-qa.christmastracker.com
    /// Debug: https://api-dev.christmastracker.com
    static let apiBaseURL: URL = {
        guard let urlString = Bundle.main.infoDictionary?["API_BASE_URL"] as? String,
              let url = URL(string: urlString) else {
            fatalError("API_BASE_URL not configured in xcconfig")
        }
        return url
    }()
    // MARK: - Cache Configuration
    /// Duration to cache network responses (seconds)
    /// Production: 900 (15 minutes)
    /// Debug: 30 (30 seconds)
    static let cacheDuration: TimeInterval = {
        guard let value = Bundle.main.infoDictionary?["CACHE_DURATION"] as? String,
              let duration = TimeInterval(value) else {
            return 900 // Default 15 minutes
        }
        return duration
    }()
    // MARK: - Session Configuration
    /// Session timeout duration (seconds)
    /// Production: 7200 (2 hours)
    /// Debug: 300 (5 minutes)
    static let sessionTimeout: TimeInterval = {
        guard let value = Bundle.main.infoDictionary?["SESSION_TIMEOUT"] as? String,
              let duration = TimeInterval(value) else {
            return 7200 // Default 2 hours
        }
        return duration
    }()
    /// Background refresh threshold (seconds)
    /// Production: 900 (15 minutes)
    /// Debug: 60 (1 minute)
    static let backgroundRefreshThreshold: TimeInterval = {
        guard let value = Bundle.main.infoDictionary?["BACKGROUND_REFRESH"] as? String,
              let duration = TimeInterval(value) else {
            return 900 // Default 15 minutes
        }
        return duration
    }()
    // MARK: - Logging Configuration
    /// Log flush interval (seconds)
    /// Production: 60 (1 minute)
    /// Debug: 15 (15 seconds)
    static let logFlushInterval: TimeInterval = {
        guard let value = Bundle.main.infoDictionary?["LOG_FLUSH_INTERVAL"] as? String,
              let duration = TimeInterval(value) else {
            return 60 // Default 60 seconds
        }
        return duration
    }()
    // MARK: - Environment
    /// Current environment (debug or production)
    static let environment: String = {
#if DEBUG
        return "debug"
#else
        return "production"
#endif
    }()
    /// Whether running in debug mode
    static let isDebug: Bool = {
#if DEBUG
        return true
#else
        return false
#endif
    }()
}
