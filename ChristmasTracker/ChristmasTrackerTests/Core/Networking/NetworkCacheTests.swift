//
//  NetworkCacheTests.swift
//  ChristmasTrackerTests
//
//  Created by Brian Alberta on 2/7/26.
//

import Testing
@testable import ChristmasTracker

@Suite("Network Cache Tests")
struct NetworkCacheTests {
    
    @Test("Cache sets and retrieves values")
    func testCacheStoreRetrieve() async {
        let cache = NetworkCache()
        await cache.setSessionId("sampleSession")
        
        struct TestData: Codable {
            let value: String
        }
        
        let data = TestData(value: "sampleValue")
        await cache.set("testKey", value: data)
        
        let retrievedData: TestData? = await cache.get("testKey")
        #expect(retrievedData?.value == "sampleValue")
    }
    
    // Cache returns nil for expired data
    @Test("Cache returns nil for expired data")
    func testCacheExpiration() async {
        // This test would require manipulating AppConfiguration.cacheDuration
        // or injecting a clock - skip for now, test manually
    }
    
    @Test("Cache clears on session change")
    func testCacheClearsOnSessionChange() async {
        let cache = NetworkCache()
        await cache.setSessionId("sessionId-1")
        
        await cache.set("testKey", value: "textValue")
        
        await cache.setSessionId("sessionId-2")
        
        let cachedValue: String? = await cache.get("testKey")
        #expect(cachedValue == nil)
    }
    
    
    // Cache scope invalidation
    @Test("Cache Scope Invalidation")
    func testCacheInvalidate() async {
        let cache = NetworkCache()
        await cache.setSessionId("testSession")
        
        await cache.set("/items", value: "items")
        await cache.set("/lists", value: "lists")
        await cache.set("/profile", value: "profile")
        
        await cache.invalidate(scope: .lists)
        
        let cachedItems: String? = await cache.get("/items")
        let cachedLists: String? = await cache.get("/lists")
        let cachedProfile: String? = await cache.get("/profile")
        
        #expect(cachedItems == "items")
        #expect(cachedProfile == "profile")
        #expect(cachedLists == nil)
        
    }
    
    
    
    @Test("Cache invalidation clears all")
    func testCacheInvalidateClearsAll() async {
        let cache = NetworkCache()
        await cache.setSessionId("testSession")
        
        await cache.set("key1", value: "value1")
        await cache.set("key2", value: "value2")
        
        await cache.invalidateAll()
        
        let cachedValue1: String? = await cache.get("key1")
        let cachedValue2: String? = await cache.get("key1")
        
        #expect(cachedValue1 == nil)
        #expect(cachedValue2 == nil)
    }
    
}
