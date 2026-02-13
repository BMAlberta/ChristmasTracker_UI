//
//  APIClient.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/3/26.
//

import Foundation

/// Protocol defining API client interface
protocol APIClient: Sendable {
    /// Perform a network request
    /// - Parameters:
    /// - method: HTTP method
    /// - path: API endpoint path
    /// - body: Optional request body
    /// - forceRefresh: Skip cache if true
    /// - Returns: Decoded response
    func request<T: Decodable & Sendable>(
        _ method: HTTPMethod,
        path: String,
        body: (any Encodable & Sendable)?,
        forceRefresh: Bool,
        cacheScope: CacheScope
    ) async throws -> T
}

enum APIError: Error, Sendable {
    case invalidResponse
    case httpError(statusCode: Int, data: Data)
    case decodingError(Error)
    case versionOutdated // 426 response
    case networkUnavailable
}

extension APIError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid server response"
        case .httpError(let statusCode, _):
            return "Server error: \(statusCode)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .versionOutdated:
            return "App version is outdated"
        case .networkUnavailable:
            return "Network connection unavailable"
        }
    }
}
