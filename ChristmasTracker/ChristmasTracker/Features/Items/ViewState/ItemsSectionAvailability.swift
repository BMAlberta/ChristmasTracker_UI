//
//  ItemsSectionAvailability.swift
//  ChristmasTracker
//
//  What the items section of the list detail screen shows when it has to choose between a
//  spinner, rows, the empty copy and a neutral "unavailable" copy. Pure: no service, no view.
//  A failed items load with nothing to show must never look like an empty list.
//

import Foundation

nonisolated enum ItemsSectionAvailability: Equatable, Sendable {
    /// A load is running and there is nothing to show yet.
    case loading
    /// There are rows to show (cached or fresh), failure or not.
    case content
    /// The items loaded and are empty.
    case empty
    /// No rows and the items load failed: neutral copy, never the empty copy.
    case unavailable

    /// Rules in order: rows are content; else a running load is loading; else a failure is
    /// unavailable; else empty.
    static func make(isLoading: Bool, hasRows: Bool, itemsFailure: ItemError?) -> ItemsSectionAvailability {
        if hasRows { return .content }
        if isLoading { return .loading }
        if itemsFailure != nil { return .unavailable }
        return .empty
    }

    static let unavailableText = "Items unavailable. Pull to refresh or tap Try Again."
}
