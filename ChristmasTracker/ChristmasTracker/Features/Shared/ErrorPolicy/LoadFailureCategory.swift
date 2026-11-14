//
//  LoadFailureCategory.swift
//  ChristmasTracker
//
//  UX1a Story U1: the pure vocabulary of load failures. No UI, no services.
//

import Foundation

/// How a failed load is treated by `LoadFailurePolicy`.
///
/// `timeout` is produced by no typed error today (they report a timeout as `network`); it is
/// reachable only through the policy inputs.
nonisolated enum LoadFailureCategory: Sendable, Equatable, Hashable, CaseIterable {
    case unreachable
    case timeout
    case server
    case rateLimited
    case forbidden
    case notFound
    case sessionEnded
    case other

    /// Connectivity failures are the ones that may be replaced by the stale-data text.
    var isConnectivity: Bool {
        switch self {
        case .unreachable, .timeout, .server:
            return true
        case .rateLimited, .forbidden, .notFound, .sessionEnded, .other:
            return false
        }
    }
}

/// What "Try Again" repeats.
nonisolated enum LoadSource: Sendable, Equatable, Hashable, CaseIterable {
    case lists
    case listDetail
    case items
    case itemDetail
    case children
    case stats
    case budgets
    case people
}
