//
//  OffListPurchaseStep.swift
//  ChristmasTracker
//
//  The post-create state of the Add Item form when the member also records the purchase. Once an
//  item exists a second create is impossible; a failed create returns to idle. Out-of-order
//  transitions are ignored.
//

import Foundation

nonisolated enum OffListPurchaseStep: Equatable, Sendable {
    case idle
    case creating
    case createdAwaitingPurchase(ListItem)
    case finished

    var allowsCreate: Bool { self == .idle }

    /// The created item while the purchase form is up, else nil.
    var pendingItem: ListItem? {
        if case .createdAwaitingPurchase(let item) = self { return item }
        return nil
    }

    /// Moves idle to creating. Any other state rejects it and stays as it is.
    @discardableResult
    mutating func beginCreate() -> Bool {
        guard self == .idle else { return false }
        self = .creating
        return true
    }

    mutating func createSucceeded(_ item: ListItem, opensPurchase: Bool) {
        guard self == .creating else { return }
        self = opensPurchase ? .createdAwaitingPurchase(item) : .finished
    }

    mutating func createFailed() {
        guard self == .creating else { return }
        self = .idle
    }

    mutating func purchaseFinished() {
        switch self {
        case .createdAwaitingPurchase, .finished:
            self = .finished
        case .idle, .creating:
            break
        }
    }
}
