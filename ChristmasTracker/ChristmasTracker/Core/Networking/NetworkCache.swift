//
//  NetworkCache.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/4/26.
//

import Foundation

/// Session-scoped network cache with selective invalidation
actor NetworkCache {
    
    static let shared = NetworkCache()
    
    // MARK: - Types
    struct CachedResponse<T> {
        let value: T
        let timestamp: Date
        let sessionId: String
    }
    
    // MARK: - Properties
    private var cache: [String: Any] = [:]
    private var currentSessionId: String?
    
    // MARK: - Session Management
    /// Set the current session ID (clears the existing cache)
    func setSessionId(_ id: String) {
        if currentSessionId != id {
            cache.removeAll()
            currentSessionId = id
            LogDebug("Cache cleared for new session", category: .cache)
        }
    }
    
    // MARK: - Cache Operations
    
    func get<T: Sendable>(_ key: String) -> T? {
        guard let cachedValue = cache[key] as? CachedResponse<T>,
              cachedValue.sessionId == currentSessionId,
              !isExpired(cachedValue.timestamp) else {
            return nil
        }
        LogDebug("Cache hit: \(key)", category: .cache)
        return cachedValue.value
    }
    
    func set<T: Sendable>(_ key: String, value: T) {
        guard let sessionId = currentSessionId else {
            LogWarning("Attemped to cache without a session", category: .cache)
            return
        }
        
        cache[key] = CachedResponse(value: value,
                                    timestamp: Date(),
                                    sessionId: sessionId)
        
        LogDebug("Cache set: \(key)", category: .cache)
    }
    
    // MARK: - Invalidation
    /// Invalidate specifc key
    func invalidate(_ key: String) {
        cache.removeValue(forKey: key)
        LogDebug("Cache invalidated: \(key)", category: .cache)
    }
    
    ///Invalidate by scope (lists, items, etc.)
    func invalidate(scope: CacheScope) {
        let initialCount = cache.count
        
        switch scope {
            
        case .none:
            return
        case .lists:
            cache = cache.filter { !$0.key.contains("/lists") }
        case .items:
            cache = cache.filter { !$0.key.contains("/items") }
        case .all, .auto:
            cache.removeAll()
        }
        
        let finalCount = cache.count
        LogDebug("Cache scope invalidated: \(scope), removed \(initialCount - finalCount) entries", category: .cache)
    }
    
    ///Invalidate all cached data
    func invalidateAll() {
        let cacheSize = cache.count
        cache.removeAll()
        LogDebug("Cache cleared. \(cacheSize) entries removed", category: .cache)
    }
    
    ///Clear cache and session
    func clear() {
        cache.removeAll()
        currentSessionId = nil
        LogDebug("Cache and session cleared", category: .cache)
    }
    
    // MARK: - Private Helpers
    
    private func isExpired(_ timestamp: Date) -> Bool {
        Date().timeIntervalSince(timestamp) >= AppConfiguration.cacheDuration
    }
}
