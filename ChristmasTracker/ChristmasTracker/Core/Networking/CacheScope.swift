//
//  CacheScope.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/4/26.
//

import Foundation

/// Defines which caches should be invalidated on write operations
enum CacheScope: Sendable {
    /// Don't invalidate any caches (profile updates, settings)
    case none
    /// Invalidate list-related caches only
    case lists
    /// Invalidate item-related caches only
    case items
    /// Invalidate all caches (catch-all for complex operations)
    case all
    /// Auto-detect scope based on API path (fallback)
    case auto
}
