//
//  ListDetailRefresh.swift
//  ChristmasTracker
//
//  The pure choice behind the list detail screen's refresh: refresh the items or load them.
//

import Foundation

nonisolated enum ListDetailRefresh {

    enum ItemsStep: Equatable, Sendable {
        case refresh
        case load
    }

    /// Refresh when the item service already holds this list, else load it.
    static func itemsStep(currentItemsListId: String?, listId: String) -> ItemsStep {
        currentItemsListId == listId ? .refresh : .load
    }
}
