//
//  AppConfiguration.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/3/26.
//

import Foundation

enum APIMode: Sendable {
    case mock
    case real

    /// Parses the API_MODE string from xcconfig/Info.plist.
    /// - "mock" (case-insensitive, trimmed) → .mock
    /// - "real" (case-insensitive, trimmed) → .real
    /// - nil, empty, or unrecognized → .real (safe default; logs a warning)
    nonisolated static func parse(_ raw: String?) -> APIMode {
        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        switch trimmed {
        case "mock": return .mock
        case "real": return .real
        default:
            if !trimmed.isEmpty {
                LogWarning("Unrecognized API_MODE value '\(trimmed)'; defaulting to real", category: .business)
            }
            return .real
        }
    }
}

/// Errors returned by `AppConfiguration.validateBaseURL(_:)`.
enum BaseURLError: Error, Sendable {
    case nilOrEmpty
    case unparseable
    case unsupportedScheme
    case emptyHost
    case nonRootPath
    case queryPresent
}

/// Reads typed configuration values from an Info.plist dictionary.
/// Pure and nonisolated — injectable for tests; never reads Bundle.main directly.
nonisolated func readConfiguration(from info: [String: Any]?) -> (
    apiMode: APIMode,
    sentryDSN: String?,
    appEnvironment: String,
    apiBaseURL: URL?,
    cacheDuration: TimeInterval,
    sessionTimeout: TimeInterval,
    backgroundRefreshThreshold: TimeInterval,
    logFlushInterval: TimeInterval
) {
    func string(_ key: String) -> String? { info?[key] as? String }
    func duration(_ key: String, default def: TimeInterval) -> TimeInterval {
        guard let s = string(key), let v = TimeInterval(s) else { return def }
        return v
    }

    let rawDSN = string("SENTRY_DSN")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let baseURL: URL? = {
        guard let raw = string("API_BASE_URL") else { return nil }
        return try? AppConfiguration.validateBaseURL(raw).get()
    }()
    return (
        apiMode: APIMode.parse(string("API_MODE")),
        sentryDSN: rawDSN.isEmpty ? nil : rawDSN,
        appEnvironment: string("APP_ENVIRONMENT") ?? "production",
        apiBaseURL: baseURL,
        cacheDuration: duration("CACHE_DURATION", default: 900),
        sessionTimeout: duration("SESSION_TIMEOUT", default: 7200),
        backgroundRefreshThreshold: duration("BACKGROUND_REFRESH", default: 900),
        logFlushInterval: duration("LOG_FLUSH_INTERVAL", default: 60)
    )
}

/// Global application configuration loaded from xcconfig via Info.plist.
struct AppConfiguration {
    // nonisolated so cacheDuration and logFlushInterval (called from Task.detached) can
    // access it without crossing an actor boundary.
    nonisolated private static let config = readConfiguration(from: Bundle.main.infoDictionary)

    // MARK: - URL Validation

    /// Validates a raw string as an API base URL.
    /// - Returns `.success(url)` when the string is an http/https URL with a non-empty host,
    ///   no non-root path, and no query string.
    /// - Returns `.failure` for nil, empty, unparseable, wrong scheme, empty host,
    ///   non-root path, or query string.
    nonisolated static func validateBaseURL(_ raw: String?) -> Result<URL, BaseURLError> {
        guard let raw, !raw.isEmpty else { return .failure(.nilOrEmpty) }
        guard let url = URL(string: raw) else { return .failure(.unparseable) }
        let scheme = url.scheme?.lowercased() ?? ""
        guard scheme == "http" || scheme == "https" else { return .failure(.unsupportedScheme) }
        guard let host = url.host, !host.isEmpty else { return .failure(.emptyHost) }
        let path = url.path
        guard path.isEmpty || path == "/" else { return .failure(.nonRootPath) }
        guard url.query == nil else { return .failure(.queryPresent) }
        return .success(url)
    }

    // MARK: - API Configuration

    /// API base URL loaded from xcconfig.
    /// Production: https://api.bmalberta.com
    /// QA: http://localhost:3010
    /// Debug: http://localhost:3010
    static let apiBaseURL: URL = {
        guard let url = config.apiBaseURL else {
            fatalError("API_BASE_URL not configured in xcconfig")
        }
        return url
    }()

    // MARK: - API Mode
    /// Whether the app should use mock or real network repositories.
    /// Driven by the API_MODE xcconfig key; never by #if DEBUG.
    static let apiMode: APIMode = config.apiMode

    // MARK: - Observability
    /// Sentry DSN from xcconfig. nil when empty (Debug/QA default).
    /// Never log or print this value.
    static let sentryDSN: String? = config.sentryDSN

    /// Current environment label for Sentry and logging (development / qa / production).
    static let appEnvironment: String = config.appEnvironment

    // MARK: - Cache Configuration
    /// Duration to cache network responses (seconds).
    nonisolated static let cacheDuration: TimeInterval = config.cacheDuration

    // MARK: - Session Configuration
    /// Session timeout duration (seconds).
    static let sessionTimeout: TimeInterval = config.sessionTimeout

    /// Background refresh threshold (seconds).
    static let backgroundRefreshThreshold: TimeInterval = config.backgroundRefreshThreshold

    // MARK: - Logging Configuration
    /// Log flush interval (seconds).
    nonisolated static let logFlushInterval: TimeInterval = config.logFlushInterval

    // MARK: - Compile-time helpers (preserved from original)
    static let environment: String = {
#if DEBUG
        return "debug"
#else
        return "production"
#endif
    }()

    static let isDebug: Bool = {
#if DEBUG
        return true
#else
        return false
#endif
    }()
}
