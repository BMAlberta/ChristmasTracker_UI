//
//  MockAPIClient.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/5/26.
//

import Foundation

/// Mock API client for development and testing
final class MockAPIClient: APIClient {
    // MARK: - Mock Configuration
    /// Simulated network delay (seconds)
    var networkDelay: TimeInterval = 0.5
    /// Should requests fail?
    var shouldFail: Bool = false
    /// Custom error to throw
    var customError: Error?
    /// Mock responses keyed by path (stored as encoded JSON data)
    private var mockResponses: [String: Data] = [:]
    
    // MARK: - Mock Data Setup
    /// Register mock response for a path
    func setMockResponse<T: Encodable>(
        _ response: T, for path: String) throws {
            let encoded = try JSONEncoder().encode(response)
            mockResponses[path] = encoded
        }
    
    // MARK: - APIClient Protocol
    func request<T: Decodable & Sendable>(_ method: HTTPMethod, path: String, body: (any Encodable & Sendable)? = nil, forceRefresh: Bool = false, cacheScope: CacheScope = .auto) async throws -> T {
        // Log the request
        LogDebug("\(method.rawValue) \(path) [MOCK]", category: .network)
        
        // Simulate network delay
        try await Task.sleep(for: .seconds(networkDelay))
        
        // Check for failure simulation
        if shouldFail {
            if let error = customError {
                throw error
            }
            throw APIError.networkUnavailable
        }
        
        // Get mock response
        guard let mockData = mockResponses[path] else {
            LogWarning("No mock data for \(path)", category: .network)
            throw APIError.invalidResponse
        }
        
        // Decode the stored JSON data
        let decoded: T
        do {
            decoded = try JSONDecoder().decode(T.self, from: mockData)
        } catch {
            LogWarning("Mock decode error: \(error)", category: .network)
            throw APIError.decodingError(error)
        }
        
        LogDebug("\(method.rawValue) \(path) [MOCK] -> Success", category: .network)
        return decoded
    }
}
// MARK: - Convenience Initializer
extension MockAPIClient {
    static func withMockData() -> MockAPIClient {
        let client = MockAPIClient()
        // Mock lists data
        let mockLists = [
            MockData.sampleGiftList,
            MockData.sampleOwnedList
        ]
        let listsResponse = DashboardListsResponse(
            success: true,
            data: ListsData(lists: mockLists)
        )
        try? client.setMockResponse(listsResponse, for: "/lists")
        return client
    }
}

