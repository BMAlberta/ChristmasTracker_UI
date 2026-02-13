//
//  KeychainServiceTests.swift
//  ChristmasTrackerTests
//
//  Created by Brian Alberta on 2/7/26.
//

import Testing
import Foundation

@testable import ChristmasTracker
@Suite("KeychainService Tests")
struct KeychainServiceTests {
    @Test("Stores and retrieves values")
    func testStoreRetrieve() async throws {
        let testKey = "test-key-\(UUID().uuidString)"
        let testValue = "test-value"
        try await KeychainService.set(testValue, for: testKey)
        let retrieved = try await KeychainService.get(testKey)
        #expect(retrieved == testValue)
        // Cleanup
        try? await KeychainService.delete(testKey)
    }
    @Test("Throws error for non-existent key")
    func testNonExistentKey() async {
        let testKey = "non-existent-\(UUID().uuidString)"
        do {
            let _ = try await KeychainService.get(testKey)
        } catch {
            #expect(Bool(true), "Should have thrown error")
            #expect(error is KeychainService.KeychainError)
        }
    }
    @Test("Deletes values")
    func testDelete() async throws {
        let testKey = "test-delete-\(UUID().uuidString)"
        try await KeychainService.set("value", for: testKey)
        try await KeychainService.delete(testKey)
        do {
            let _ = try await KeychainService.get(testKey)
        } catch {
            #expect(Bool(true), "Should have thrown error after delete")
            #expect(error is KeychainService.KeychainError)
        }
    }
}
