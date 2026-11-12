//
//  ItemMockSupport.swift
//  ChristmasTrackerTests
//
//  Story I3c-C: small helpers shared by the MockItemRepository and AppDependencies tests.
//
//  - `CapabilitySwitch`: a Sendable box the `capabilities` closure of `MockItemRepository` reads,
//    so one test can change the flags between two calls (the closure is `@Sendable`). Backed by a
//    `Mutex`, so no unchecked Sendable is needed.
//  - `MockItemRepository.setDelay`: the mock sleeps `delay` seconds per call; tests set it to 0
//    (same helper the list mock tests use). ASSUMES the mock keeps its `var delay: TimeInterval`
//    (the current mock has it); reported as an assumption to the Orchestrator.
//  - `seededItems`: the items the mock ships with, discovered through its public API over the
//    MockListData list ids (the Gate 1 addendum fixes no seed content, so tests never hard-code
//    an item id).
//

import Foundation
import Synchronization
@testable import ChristmasTracker

nonisolated final class CapabilitySwitch: Sendable {
    private let storage: Mutex<ListCapabilities>

    init(_ initial: ListCapabilities) {
        storage = Mutex(initial)
    }

    var current: ListCapabilities {
        get { storage.withLock { $0 } }
        set { storage.withLock { $0 = newValue } }
    }
}

extension MockItemRepository {
    func setDelay(_ value: TimeInterval) {
        delay = value
    }
}

enum ItemMockSupport {

    /// A fake current user for the mock, distinct from every seeded creator by construction.
    static let me = ListItemPerson(id: "test-user-me", displayName: "Test Me")

    /// A mock whose capabilities follow the switch and whose delay is 0.
    static func makeMock(_ capabilities: CapabilitySwitch, currentUser: ListItemPerson = me) async -> MockItemRepository {
        let repo = MockItemRepository(capabilities: { _ in capabilities.current }, currentUser: currentUser)
        await repo.setDelay(0)
        return repo
    }

    /// A mock with the same capabilities for every list.
    static func makeMock(_ capabilities: ListCapabilities, currentUser: ListItemPerson = me) async -> MockItemRepository {
        let repo = MockItemRepository(capabilities: { _ in capabilities }, currentUser: currentUser)
        await repo.setDelay(0)
        return repo
    }

    /// Everything the mock ships with, read with full visibility (gift activity and off-list items).
    static func seededItems() async throws -> [ListItem] {
        let repo = await makeMock(ItemFixtures.Persona.owner.capabilities)
        var all: [ListItem] = []
        for list in MockListData.allScenarios {
            all += try await repo.fetchItems(listId: list.id)
        }
        return all
    }

    /// The list ids that hold seeded items (for building a viewer-side mock over the same data).
    static func seededListIds() async throws -> [String] {
        Array(Set(try await seededItems().map(\.listId))).sorted()
    }
}
