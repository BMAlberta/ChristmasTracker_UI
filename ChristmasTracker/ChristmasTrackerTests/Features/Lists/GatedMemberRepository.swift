//
//  GatedMemberRepository.swift
//  ChristmasTrackerTests
//
//  Story I3b-M2: a scripted, optionally gated MemberRepository fake for the ListService tests.
//  Same determinism rules as GatedListRepository (see HeldCallGate): no sleeps, no polling.
//  A MainActor class, never an actor, because the protocol methods are MainActor here.
//

import Foundation
@testable import ChristmasTracker

@MainActor
final class GatedMemberRepository: MemberRepository {

    enum Call: Equatable, Sendable {
        case addMember(String)
        case removeMember(String, String)
    }

    struct Step<Value: Sendable>: Sendable {
        var outcome: Result<Value, any Error>
        var held: Bool
    }

    // MARK: Configuration

    let gate = HeldCallGate<Call>()
    var callLog: RepositoryCallLog?

    var honorsCancellation: Bool {
        get { gate.honorsCancellation }
        set { gate.honorsCancellation = newValue }
    }

    // MARK: Recorded calls

    private(set) var addMemberCount = 0
    private(set) var removeMemberCount = 0
    private(set) var addedRequests: [(listId: String, input: AddMemberInput)] = []
    private(set) var removedRequests: [(listId: String, userId: String)] = []

    // MARK: Scripts

    private var addSteps: [Step<ListMember>] = []
    private var removeSteps: [Step<Void>] = []

    func enqueueAddMember(_ outcome: Result<ListMember, any Error>, held: Bool = false) {
        addSteps.append(Step(outcome: outcome, held: held))
    }

    func enqueueRemoveMember(_ outcome: Result<Void, any Error>, held: Bool = false) {
        removeSteps.append(Step(outcome: outcome, held: held))
    }

    // MARK: MemberRepository

    @MainActor func addMember(listId: String, _ input: AddMemberInput) async throws -> ListMember {
        addMemberCount += 1
        addedRequests.append((listId: listId, input: input))
        callLog?.record("addMember:\(listId)")
        let step = addSteps.isEmpty
            ? Step<ListMember>(outcome: .failure(ListError.server), held: false)
            : addSteps.removeFirst()
        if step.held { try await gate.hold(.addMember(listId)) }
        return try step.outcome.get()
    }

    @MainActor func removeMember(listId: String, userId: String) async throws {
        removeMemberCount += 1
        removedRequests.append((listId: listId, userId: userId))
        callLog?.record("removeMember:\(listId):\(userId)")
        let step = removeSteps.isEmpty
            ? Step<Void>(outcome: .failure(ListError.server), held: false)
            : removeSteps.removeFirst()
        if step.held { try await gate.hold(.removeMember(listId, userId)) }
        try step.outcome.get()
    }
}
