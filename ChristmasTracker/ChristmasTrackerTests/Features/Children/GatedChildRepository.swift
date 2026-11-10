//
//  GatedChildRepository.swift
//  ChristmasTrackerTests
//
//  Story I3b-M2: a scripted, optionally gated ChildRepository fake for the ChildService tests.
//  Same determinism rules as GatedListRepository (see HeldCallGate): no sleeps, no polling.
//  A MainActor class, never an actor, because the protocol methods are MainActor here.
//

import Foundation
@testable import ChristmasTracker

@MainActor
final class GatedChildRepository: ChildRepository {

    enum Call: Equatable, Sendable {
        case fetchChildren
        case createChild
        case deleteChild(String)
    }

    struct Step<Value: Sendable>: Sendable {
        var outcome: Result<Value, any Error>
        var held: Bool
    }

    // MARK: Configuration

    let gate = HeldCallGate<Call>()

    var honorsCancellation: Bool {
        get { gate.honorsCancellation }
        set { gate.honorsCancellation = newValue }
    }

    // MARK: Recorded calls

    private(set) var fetchChildrenCount = 0
    private(set) var createChildCount = 0
    private(set) var deleteChildCount = 0
    private(set) var createdInputs: [CreateChildInput] = []
    private(set) var deletedIds: [String] = []

    // MARK: Scripts

    private var fetchSteps: [Step<[Child]>] = []
    private var createSteps: [Step<Child>] = []
    private var deleteSteps: [Step<Void>] = []

    func enqueueFetchChildren(_ outcome: Result<[Child], any Error>, held: Bool = false) {
        fetchSteps.append(Step(outcome: outcome, held: held))
    }

    func enqueueCreateChild(_ outcome: Result<Child, any Error>, held: Bool = false) {
        createSteps.append(Step(outcome: outcome, held: held))
    }

    func enqueueDeleteChild(_ outcome: Result<Void, any Error>, held: Bool = false) {
        deleteSteps.append(Step(outcome: outcome, held: held))
    }

    // MARK: ChildRepository

    @MainActor func fetchChildren() async throws -> [Child] {
        fetchChildrenCount += 1
        let step = fetchSteps.isEmpty
            ? Step<[Child]>(outcome: .failure(ChildError.server), held: false)
            : fetchSteps.removeFirst()
        if step.held { try await gate.hold(.fetchChildren) }
        return try step.outcome.get()
    }

    @MainActor func createChild(_ input: CreateChildInput) async throws -> Child {
        createChildCount += 1
        createdInputs.append(input)
        let step = createSteps.isEmpty
            ? Step<Child>(outcome: .failure(ChildError.server), held: false)
            : createSteps.removeFirst()
        if step.held { try await gate.hold(.createChild) }
        return try step.outcome.get()
    }

    @MainActor func deleteChild(id: String) async throws {
        deleteChildCount += 1
        deletedIds.append(id)
        let step = deleteSteps.isEmpty
            ? Step<Void>(outcome: .failure(ChildError.server), held: false)
            : deleteSteps.removeFirst()
        if step.held { try await gate.hold(.deleteChild(id)) }
        try step.outcome.get()
    }
}
