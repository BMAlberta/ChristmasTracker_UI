//
//  GatedListRepository.swift
//  ChristmasTrackerTests
//
//  Story I3a-L2: a scripted, optionally gated ListRepository fake for the ListService tests.
//
//  Determinism: no sleeps and no polling. Each call pops one scripted step. A step marked
//  `held` suspends the call on a gate until the test releases it, and announces itself through
//  `nextHeldCall()` (a continuation handshake), so a test can wait until the service has really
//  entered the repository, act (for example tear the session down), and then release.
//
//  When `honorsCancellation` is true a held call ends early with CancellationError if its task is
//  cancelled; otherwise it keeps waiting until released (the stale-result case).
//
//  Also hosts the small MockListRepository helpers the older service tests use.
//

import Foundation
@testable import ChristmasTracker

@MainActor
final class GatedListRepository: ListRepository {

    enum Call: Equatable, Sendable {
        case fetchLists
        case fetchListDetail(String)
        case createList
        case updateList(String)
        case deleteList(String)
    }

    struct Step<Value: Sendable>: Sendable {
        var outcome: Result<Value, any Error>
        var held: Bool
    }

    // MARK: Configuration

    var honorsCancellation = false

    /// I3b-M2: optional shared log so a test can assert the order of calls across repositories.
    var callLog: RepositoryCallLog?

    // MARK: Recorded calls

    private(set) var fetchListsCount = 0
    private(set) var fetchListDetailCount = 0
    private(set) var createListCount = 0
    private(set) var updateListCount = 0
    private(set) var deleteListCount = 0
    private(set) var createdInputs: [CreateListInput] = []
    private(set) var updatedInputs: [UpdateListInput] = []

    // MARK: Scripts

    private var listSteps: [Step<[GiftList]>] = []
    private var detailSteps: [Step<ListDetail>] = []
    private var createSteps: [Step<ListDetail>] = []
    private var updateSteps: [Step<ListDetail>] = []
    private var deleteSteps: [Step<Void>] = []

    func enqueueFetchLists(_ outcome: Result<[GiftList], any Error>, held: Bool = false) {
        listSteps.append(Step(outcome: outcome, held: held))
    }

    func enqueueFetchListDetail(_ outcome: Result<ListDetail, any Error>, held: Bool = false) {
        detailSteps.append(Step(outcome: outcome, held: held))
    }

    func enqueueCreateList(_ outcome: Result<ListDetail, any Error>, held: Bool = false) {
        createSteps.append(Step(outcome: outcome, held: held))
    }

    func enqueueUpdateList(_ outcome: Result<ListDetail, any Error>, held: Bool = false) {
        updateSteps.append(Step(outcome: outcome, held: held))
    }

    func enqueueDeleteList(_ outcome: Result<Void, any Error>, held: Bool = false) {
        deleteSteps.append(Step(outcome: outcome, held: held))
    }

    // MARK: Handshake

    private var unclaimedHeld: [Call] = []
    private var heldWaiters: [CheckedContinuation<Call, Never>] = []
    private var gates: [AsyncStream<Void>.Continuation] = []
    private var released: [Bool] = []

    /// Suspends until a held call has entered the repository (or returns at once if one already
    /// has and nobody has claimed it yet). Each held call is claimed exactly once, in order.
    @discardableResult
    func nextHeldCall() async -> Call {
        if !unclaimedHeld.isEmpty {
            return unclaimedHeld.removeFirst()
        }
        return await withCheckedContinuation { heldWaiters.append($0) }
    }

    /// Releases the oldest held call that has not been released yet. No-op when there is none.
    func releaseNext() {
        guard let index = released.firstIndex(of: false) else { return }
        release(at: index)
    }

    /// Releases the held call with the given zero-based arrival index (the order in which held
    /// calls entered the repository). No-op when out of range or already released.
    func release(at index: Int) {
        guard gates.indices.contains(index), !released[index] else { return }
        released[index] = true
        gates[index].yield(())
        gates[index].finish()
    }

    /// Releases every held call that is still waiting.
    func releaseAll() {
        for index in gates.indices {
            release(at: index)
        }
    }

    private func announceHeld(_ call: Call) {
        if heldWaiters.isEmpty {
            unclaimedHeld.append(call)
        } else {
            heldWaiters.removeFirst().resume(returning: call)
        }
    }

    private func hold(_ call: Call) async throws {
        let (stream, continuation) = AsyncStream.makeStream(of: Void.self)
        gates.append(continuation)
        released.append(false)
        announceHeld(call)
        if honorsCancellation {
            // Iterating an AsyncStream ends early when the task is cancelled.
            for await _ in stream { break }
            try Task.checkCancellation()
        } else {
            // An unstructured task is not cancelled with its parent, so this keeps waiting.
            await Task { for await _ in stream { break } }.value
        }
    }

    // MARK: ListRepository

    @MainActor func fetchLists() async throws -> [GiftList] {
        fetchListsCount += 1
        let step = listSteps.isEmpty ? Step(outcome: .success([GiftList]()), held: false) : listSteps.removeFirst()
        if step.held { try await hold(.fetchLists) }
        return try step.outcome.get()
    }

    @MainActor func fetchListDetail(id: String) async throws -> ListDetail {
        fetchListDetailCount += 1
        callLog?.record("fetchListDetail:\(id)")
        let step = detailSteps.isEmpty
            ? Step<ListDetail>(outcome: .failure(ListError.server), held: false)
            : detailSteps.removeFirst()
        if step.held { try await hold(.fetchListDetail(id)) }
        return try step.outcome.get()
    }

    @MainActor func createList(_ input: CreateListInput) async throws -> ListDetail {
        createListCount += 1
        createdInputs.append(input)
        let step = createSteps.isEmpty
            ? Step<ListDetail>(outcome: .failure(ListError.server), held: false)
            : createSteps.removeFirst()
        if step.held { try await hold(.createList) }
        return try step.outcome.get()
    }

    @MainActor func updateList(id: String, _ input: UpdateListInput) async throws -> ListDetail {
        updateListCount += 1
        updatedInputs.append(input)
        callLog?.record("updateList:\(id)")
        let step = updateSteps.isEmpty
            ? Step<ListDetail>(outcome: .failure(ListError.server), held: false)
            : updateSteps.removeFirst()
        if step.held { try await hold(.updateList(id)) }
        return try step.outcome.get()
    }

    @MainActor func deleteList(id: String) async throws {
        deleteListCount += 1
        let step = deleteSteps.isEmpty
            ? Step<Void>(outcome: .failure(ListError.server), held: false)
            : deleteSteps.removeFirst()
        if step.held { try await hold(.deleteList(id)) }
        try step.outcome.get()
    }
}

// MARK: - MockListRepository test helpers

extension MockListRepository {
    func setShouldFail(_ value: Bool) {
        shouldFail = value
    }

    func setDelay(_ value: TimeInterval) {
        delay = value
    }
}
