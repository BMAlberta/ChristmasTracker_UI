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
    func request<T: Decodable>(
        _ method: HTTPMethod,
        path: String,
        body: (any Encodable & Sendable)?,
        forceRefresh: Bool
    ) async throws -> T
}

enum APIError: Error, Sendable {
    case invalidResponse
    case httpError(statusCode: Int, data: Data)
    case decodingError(Error)
}
