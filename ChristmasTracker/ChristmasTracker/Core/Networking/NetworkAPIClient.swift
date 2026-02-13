//
//  NetworkAPIClient.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/5/26.
//

import Foundation

// Core/Networking/NetworkAPIClient.swift
import Foundation

/// Production API client with real network requests
/// CLASS (not actor): No mutable state, URLSession is thread-safe
final class NetworkAPIClient: APIClient, Sendable {
    
    private let baseURL: URL
    private let session: URLSession
    private let cache: NetworkCache
    private let channel = "MOB"
    private let deviceFingerprint: String
    
    init(
        baseURL: URL = AppConfiguration.apiBaseURL,
        session: URLSession = .shared,
        cache: NetworkCache = .shared,
    ) {
        self.baseURL = baseURL
        self.session = session
        self.cache = cache
        self.deviceFingerprint = (try? DeviceFingerprintService.getFingerprint()) ?? "unknown"
    }
    
    func request<T: Decodable & Sendable>(
        _ method: HTTPMethod,
        path: String,
        body: (any Encodable & Sendable)? = nil,
        forceRefresh: Bool = false,
        cacheScope: CacheScope = .auto
    ) async throws -> T {
        
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = method.rawValue
    
        appendCommonHeaders(to: &request)
        
        if let body = body {
            do {
                request.httpBody = try JSONEncoder().encode(body)
            } catch {
                throw APIError.decodingError(error)
            }
        }
        
        // Check cache
        if method == .get && !forceRefresh {
            if let cached: T = await cache.get(path) {
                LogDebug("Cache hit: \(path)", category: .cache)
                return cached
            }
        }
        
        // Perform request
        LogDebug("\(method.rawValue) \(path)", category: .network)
        let startTime = Date()
        
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            LogError("Network request failed: \(error)", category: .network)
            throw APIError.networkUnavailable
        }
        
        let duration = Date().timeIntervalSince(startTime)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        LogInfo(
            "\(method.rawValue) \(path) -> \(httpResponse.statusCode) (\(String(format: "%.2f", duration))s)",
            category: .network
        )
        
        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 {
                handle401Unauthorized()
            }
            
            if httpResponse.statusCode == 426 {
                handle426UpgradeRequired(data: data)
                throw APIError.versionOutdated
            }
            
            throw APIError.httpError(statusCode: httpResponse.statusCode, data: data)
        }
        
        let decoded: T
        do {
            decoded = try JSONDecoder().decode(T.self, from: data)
        } catch {
            LogError("Decode error: \(error)", category: .network)
            throw APIError.decodingError(error)
        }
        
        if method == .get {
            await cache.set(path, value: decoded)
        }
        
        if method != .get {
            await handleCacheEviction(scope: cacheScope, path: path)
        }
        
        return decoded
    }
    
    private func appendCommonHeaders(to request: inout URLRequest) {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            request.setValue(version, forHTTPHeaderField: "X-App-Version")
            request.setValue("ios", forHTTPHeaderField: "X-Platform")
        }
        request.setValue(self.deviceFingerprint, forHTTPHeaderField: "X-Device-Fingerprint")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    }
    
    private func handleCacheEviction(scope: CacheScope, path: String) async {
        switch scope {
        case .none:
            break
        case .lists:
            await cache.invalidate(scope: .lists)
        case .items:
            await cache.invalidate(scope: .items)
        case .all:
            await cache.invalidateAll()
        case .auto:
            if path.contains("/lists") {
                await cache.invalidate(scope: .lists)
            } else if path.contains("/items") {
                await cache.invalidate(scope: .items)
            }
        }
    }
    
    private func handle401Unauthorized() {
        Task { @MainActor in
            NotificationCenter.default.post(name: .unauthorizedRequest, object: nil)
        }
        LogWarning("401 Unauthorized - session expired", category: .auth)
    }
    
    private func handle426UpgradeRequired(data: Data) {
        do {
            let response = try JSONDecoder().decode(VersionErrorResponse.self, from: data)
            guard let url = URL(string: response.updateUrl) else { return }
            
            Task { @MainActor in
                NotificationCenter.default.post(
                    name: .versionUpdateRequired,
                    object: VersionStatus.forceUpdate(message: response.message, url: url)
                )
            }
            
            LogWarning("426 Upgrade Required", category: .auth)
        } catch {
            LogError("Failed to parse 426 response: \(error)", category: .network)
        }
    }
}

// Supporting types
struct VersionErrorResponse: Codable {
    let error: String
    let code: String
    let message: String
    let minimumVersion: String
    let currentVersion: String
    let latestVersion: String
    let updateUrl: String
}

enum VersionStatus {
    case forceUpdate(message: String, url: URL)
}

extension Notification.Name {
    static let unauthorizedRequest = Notification.Name("unauthorizedRequest")
    static let versionUpdateRequired = Notification.Name("versionUpdateRequired")
}
