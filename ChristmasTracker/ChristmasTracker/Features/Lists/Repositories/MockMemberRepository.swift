//
//  MockMemberRepository.swift
//  ChristmasTracker
//
//  Deterministic member operations for mock mode and previews. It works on the SAME
//  MockListRepository instance as the list repository (shared state), so a member added or a
//  list left here shows up in the lists and details the list mock serves.
//

import Foundation

nonisolated final class MockMemberRepository: MemberRepository {

    private let listRepository: MockListRepository

    init(listRepository: MockListRepository) {
        self.listRepository = listRepository
    }

    // Mock repository: intentionally uninstrumented. No delay of its own: it shares the list mock's.
    func addMember(listId: String, _ input: AddMemberInput) async throws -> ListMember {
        LogDebug("Mock addMember", category: .business)
        return try await listRepository.addMemberToList(id: listId, input)
    }

    // Mock repository: intentionally uninstrumented.
    func removeMember(listId: String, userId: String) async throws {
        LogDebug("Mock removeMember", category: .business)
        try await listRepository.removeMemberFromList(id: listId, userId: userId)
    }
}
