//
//  MemberRepository.swift
//  ChristmasTracker
//
//  The member operations of a list. Every failure is a ListError. Leaving a list is
//  `removeMember` with the caller's own user id: the server has no separate operation.
//

import Foundation

nonisolated protocol MemberRepository: Repository {

    /// Add a member to a list (the server adds them as ACTIVE at once, no invitation).
    /// - Returns: the new member only. The roster is never built from it: callers refetch the detail.
    func addMember(listId: String, _ input: AddMemberInput) async throws -> ListMember

    /// Remove a member from a list, or leave it when `userId` is the caller's own id.
    func removeMember(listId: String, userId: String) async throws
}
