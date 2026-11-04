//
//  SessionClearable.swift
//  ChristmasTracker

import Foundation

/// Adopted by any type that holds session-scoped state and must be cleared on logout
/// or session expiry.
internal protocol SessionClearable: AnyObject, Sendable {
    func clearForSession() async throws
}

/// The reason a session teardown was triggered.
internal enum TeardownReason: Sendable {
    case userLogout
    case sessionExpired
    case forcedUpdate
    case lockFallback
}

/// Returns the production clearable list for the session manager.
/// AuthenticationService is excluded — it self-clears in AuthenticationService.logout()
/// because constructing it requires an already-initialised SessionManager (circular dependency).
internal func makeProductionClearables(
    listDataStore: ListDataStore,
    itemDataStore: ItemDataStore,
    listService: ListService,
    itemService: ItemService,
    networkCache: NetworkCache
) -> [any SessionClearable] {
    [listDataStore, itemDataStore, listService, itemService, networkCache]
}
