//
//  MockChildRepository.swift
//  ChristmasTracker
//
//  Deterministic children for mock mode and previews. It works on the SAME MockListRepository
//  instance as the list repository (shared state): the mock starts with one child who has a
//  list, a new child gets a deterministic id, and a child with a list cannot be deleted.
//

import Foundation

nonisolated final class MockChildRepository: ChildRepository {

    private let listRepository: MockListRepository

    init(listRepository: MockListRepository) {
        self.listRepository = listRepository
    }

    // Mock repository: intentionally uninstrumented. No delay of its own: it shares the list mock's.
    func fetchChildren() async throws -> [Child] {
        LogDebug("Mock fetchChildren", category: .business)
        return try await listRepository.childrenOfUser()
    }

    // Mock repository: intentionally uninstrumented.
    func createChild(_ input: CreateChildInput) async throws -> Child {
        LogDebug("Mock createChild", category: .business)
        return try await listRepository.addChild(input)
    }

    // Mock repository: intentionally uninstrumented.
    func deleteChild(id: String) async throws {
        LogDebug("Mock deleteChild", category: .business)
        try await listRepository.removeChild(id: id)
    }
}
