//
//  ChildRepository.swift
//  ChristmasTracker
//
//  The children the signed-in user manages. Every failure is a ChildError.
//

import Foundation

nonisolated protocol ChildRepository: Repository {

    /// The children of the signed-in user, in server order.
    func fetchChildren() async throws -> [Child]

    /// Create a child. The child has no email or password and can never sign in.
    func createChild(_ input: CreateChildInput) async throws -> Child

    /// Delete a child (soft delete). Fails with `childHasLists` while the child still has an active (ACTIVE or DRAFT) list.
    func deleteChild(id: String) async throws
}
