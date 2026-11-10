//
//  ChildServiceSessionSafetyTests.swift
//  ChristmasTrackerTests
//
//  Story I3b-M2: ChildService is safe against sign-out, user switching and cancellation, and
//  clearForSession() empties everything. Teardown runs the way the app does it
//  (SessionManager.teardown calls clearForSession), and clearForSession is also called directly.
//
//  Determinism: gated fake with the nextHeldCall() handshake; no sleeps, no yield loops.
//

import Foundation
import Testing
@testable import ChristmasTracker

/// The three ChildService operations that talk to the repository.
nonisolated enum ChildServiceOp: CaseIterable, Sendable, CustomTestStringConvertible {
    case load, add, delete

    var testDescription: String {
        switch self {
        case .load: "loadChildren"
        case .add: "addChild"
        case .delete: "deleteChild"
        }
    }

    /// Queues ONE held step for this operation: success (fake data) or the given failure.
    @MainActor
    func script(_ repo: GatedChildRepository, failing error: ChildError?) {
        func outcome<T>(_ value: T) -> Result<T, any Error> {
            if let error { return .failure(error) }
            return .success(value)
        }
        switch self {
        case .load:
            repo.enqueueFetchChildren(outcome(ChildFixtures.twoChildren()), held: true)
        case .add:
            repo.enqueueCreateChild(
                outcome(ChildFixtures.child(id: "child-3", firstName: "Eli", lastName: "Example")),
                held: true
            )
        case .delete:
            repo.enqueueDeleteChild(outcome(()), held: true)
        }
    }

    /// Runs the operation; a thrown error is swallowed (tests assert on service state).
    @MainActor
    func run(_ service: ChildService) async {
        switch self {
        case .load:
            await service.loadChildren()
        case .add:
            _ = try? await service.addChild(
                CreateChildInput(firstName: "Eli", lastName: "Example", displayName: nil, relationship: .parent)
            )
        case .delete:
            _ = try? await service.deleteChild(id: "child-1")
        }
    }
}

@Suite("ChildService session safety", .timeLimit(.minutes(1)))
@MainActor
struct ChildServiceSessionSafetyTests {

    private struct SUT {
        let service: ChildService
        let repo: GatedChildRepository
        let manager: SessionManager
    }

    private func makeSUT(honorsCancellation: Bool = false) async -> SUT {
        let repo = GatedChildRepository()
        repo.honorsCancellation = honorsCancellation
        let service = ChildService(repository: repo)
        let manager = SessionManager(initialClearables: [])
        await manager.register(service)
        return SUT(service: service, repo: repo, manager: manager)
    }

    /// A service that already holds the two fixture children (phase loaded).
    private func makeLoadedSUT(honorsCancellation: Bool = false) async -> SUT {
        let sut = await makeSUT(honorsCancellation: honorsCancellation)
        sut.repo.enqueueFetchChildren(.success(ChildFixtures.twoChildren()))
        await sut.service.loadChildren()
        return sut
    }

    private func expectCleared(_ sut: SUT) {
        #expect(sut.service.children.isEmpty, "children must stay empty")
        #expect(sut.service.error == nil, "no error may be set after the session ended")
        #expect(sut.service.phase == .idle, "the phase must stay idle after the session ended")
        #expect(sut.service.isMutating == false)
    }

    // MARK: - Teardown during an in-flight operation

    @Test(
        "an operation that completes after teardown writes nothing",
        arguments: ChildServiceOp.allCases, [false, true]
    )
    func inFlightSuccessAfterTeardown(op: ChildServiceOp, honorsCancellation: Bool) async {
        let sut = await makeLoadedSUT(honorsCancellation: honorsCancellation)
        op.script(sut.repo, failing: nil)
        let task = Task { await op.run(sut.service) }
        await sut.repo.gate.nextHeldCall()

        await sut.manager.teardown(reason: .userLogout)
        sut.repo.gate.releaseAll()
        await task.value

        expectCleared(sut)
    }

    @Test(
        "an operation that fails after teardown sets no error",
        arguments: ChildServiceOp.allCases, [ChildError.server, .network, .childNotFound, .childHasLists]
    )
    func inFlightFailureAfterTeardown(op: ChildServiceOp, error: ChildError) async {
        let sut = await makeLoadedSUT()
        op.script(sut.repo, failing: error)
        let task = Task { await op.run(sut.service) }
        await sut.repo.gate.nextHeldCall()

        await sut.manager.teardown(reason: .sessionExpired)
        sut.repo.gate.releaseAll()
        await task.value

        expectCleared(sut)
    }

    @Test("after an operation discarded by teardown, the next load goes to the repository", arguments: ChildServiceOp.allCases)
    func nextLoadAfterDiscardedOperation(op: ChildServiceOp) async {
        let sut = await makeLoadedSUT()
        op.script(sut.repo, failing: nil)
        let task = Task { await op.run(sut.service) }
        await sut.repo.gate.nextHeldCall()
        await sut.manager.teardown(reason: .userLogout)
        sut.repo.gate.releaseAll()
        await task.value
        let before = sut.repo.fetchChildrenCount
        let own = [ChildFixtures.child(id: "child-b", firstName: "Bea", lastName: "Bee")]
        sut.repo.enqueueFetchChildren(.success(own))

        await sut.service.loadChildren()

        #expect(sut.repo.fetchChildrenCount == before + 1)
        #expect(sut.service.children == own)
        #expect(sut.service.phase == .loaded)
        #expect(sut.service.error == nil)
    }

    // MARK: - User switch

    @Test("user switch: B loads while A's load is held; A's late result never shows")
    func userSwitchLoad() async {
        let sut = await makeSUT()
        let childOfB = [ChildFixtures.child(id: "child-b", firstName: "Bea", lastName: "Bee")]
        sut.repo.enqueueFetchChildren(.success(ChildFixtures.twoChildren()), held: true)   // user A
        sut.repo.enqueueFetchChildren(.success(childOfB))                                  // user B
        let loadA = Task { await sut.service.loadChildren() }
        await sut.repo.gate.nextHeldCall()

        await sut.manager.teardown(reason: .userLogout)
        await sut.service.loadChildren()                                                   // user B
        #expect(sut.service.children == childOfB)

        sut.repo.gate.releaseAll()
        await loadA.value

        #expect(sut.service.children == childOfB, "A's children must not replace or join B's")
        #expect(sut.service.phase == .loaded)
        #expect(sut.service.error == nil)
    }

    @Test("user switch: A's late failure does not put an error or a failed phase on B")
    func userSwitchLateFailure() async {
        let sut = await makeSUT()
        let childOfB = [ChildFixtures.child(id: "child-b", firstName: "Bea", lastName: "Bee")]
        sut.repo.enqueueFetchChildren(.failure(ChildError.network), held: true)           // user A fails late
        sut.repo.enqueueFetchChildren(.success(childOfB))
        let loadA = Task { await sut.service.loadChildren() }
        await sut.repo.gate.nextHeldCall()
        await sut.manager.teardown(reason: .userLogout)
        await sut.service.loadChildren()

        sut.repo.gate.releaseAll()
        await loadA.value

        #expect(sut.service.error == nil)
        #expect(sut.service.phase == .loaded)
        #expect(sut.service.children == childOfB)
    }

    @Test("user switch: A's delete still in flight does not remove B's child with the same id")
    func userSwitchDelete() async {
        let sut = await makeLoadedSUT()                                                    // user A
        sut.repo.enqueueDeleteChild(.success(()), held: true)
        let deleteTask = Task { await ChildServiceOp.delete.run(sut.service) }
        await sut.repo.gate.nextHeldCall()

        await sut.manager.teardown(reason: .userLogout)
        sut.repo.enqueueFetchChildren(.success(ChildFixtures.twoChildren()))               // B happens to see the same ids
        await sut.service.loadChildren()
        sut.repo.gate.releaseAll()
        await deleteTask.value

        #expect(sut.service.children == ChildFixtures.twoChildren())
        #expect(sut.service.error == nil)
    }

    @Test("user switch: A's add still in flight does not append to B's children")
    func userSwitchAdd() async {
        let sut = await makeLoadedSUT()                                                    // user A
        ChildServiceOp.add.script(sut.repo, failing: nil)
        let addTask = Task { await ChildServiceOp.add.run(sut.service) }
        await sut.repo.gate.nextHeldCall()

        await sut.manager.teardown(reason: .userLogout)
        let childOfB = [ChildFixtures.child(id: "child-b", firstName: "Bea", lastName: "Bee")]
        sut.repo.enqueueFetchChildren(.success(childOfB))
        await sut.service.loadChildren()
        sut.repo.gate.releaseAll()
        await addTask.value

        #expect(sut.service.children == childOfB)
    }

    // MARK: - Cancellation

    @Test("cancelling the caller sets no error and no failed phase", arguments: ChildServiceOp.allCases)
    func cancellationSetsNoError(op: ChildServiceOp) async {
        let sut = await makeLoadedSUT(honorsCancellation: true)
        op.script(sut.repo, failing: nil)
        let task = Task { await op.run(sut.service) }
        await sut.repo.gate.nextHeldCall()

        task.cancel()
        sut.repo.gate.releaseAll()
        await task.value

        #expect(sut.service.error == nil, "cancellation is not shown to the user")
        #expect(sut.service.isMutating == false)
        if case .failed = sut.service.phase {
            Issue.record("a cancelled call must not leave the phase failed")
        }
    }

    @Test("a repository that fails with CancellationError sets no error", arguments: ChildServiceOp.allCases)
    func repositoryCancellationErrorSetsNoError(op: ChildServiceOp) async {
        let sut = await makeLoadedSUT()
        switch op {
        case .load: sut.repo.enqueueFetchChildren(.failure(CancellationError()))
        case .add: sut.repo.enqueueCreateChild(.failure(CancellationError()))
        case .delete: sut.repo.enqueueDeleteChild(.failure(CancellationError()))
        }

        await op.run(sut.service)

        #expect(sut.service.error == nil)
        #expect(sut.service.isMutating == false)
        if case .failed = sut.service.phase {
            Issue.record("a cancelled call must not leave the phase failed")
        }
    }

    // MARK: - clearForSession

    @Test("clearForSession empties children and error and returns the phase to idle")
    func clearForSessionEmptiesEverything() async throws {
        let sut = await makeLoadedSUT()
        sut.repo.enqueueDeleteChild(.failure(ChildError.childHasLists))
        _ = try? await sut.service.deleteChild(id: "child-1")
        #expect(sut.service.error != nil, "precondition")
        #expect(sut.service.children.isEmpty == false, "precondition")

        try await sut.service.clearForSession()

        #expect(sut.service.children.isEmpty)
        #expect(sut.service.error == nil)
        #expect(sut.service.phase == .idle)
        #expect(sut.service.isMutating == false)
    }

    @Test("clearForSession after a failed load returns the phase to idle")
    func clearForSessionAfterFailedLoad() async throws {
        let sut = await makeSUT()
        sut.repo.enqueueFetchChildren(.failure(ChildError.server))
        await sut.service.loadChildren()
        #expect(sut.service.phase == .failed(.server), "precondition")

        try await sut.service.clearForSession()

        #expect(sut.service.phase == .idle)
    }

    @Test("teardown through the SessionManager clears a populated service")
    func teardownClearsPopulatedService() async {
        let sut = await makeLoadedSUT()
        #expect(sut.service.children.count == 2, "precondition")

        await sut.manager.teardown(reason: .userLogout)

        expectCleared(sut)
    }

    @Test("clearForSession cancels work that is in flight (no release needed)", arguments: ChildServiceOp.allCases)
    func clearForSessionCancelsInFlight(op: ChildServiceOp) async throws {
        let sut = await makeLoadedSUT(honorsCancellation: true)
        op.script(sut.repo, failing: nil)
        let task = Task { await op.run(sut.service) }
        await sut.repo.gate.nextHeldCall()

        try await sut.service.clearForSession()
        // The fake honors cancellation: if the service cancelled the call, this returns without
        // anyone releasing the gate (the suite time limit turns a hang into a failure).
        await task.value

        expectCleared(sut)
    }

    @Test("a second clearForSession is harmless and the service loads again afterwards")
    func repeatedClearIsHarmless() async throws {
        let sut = await makeLoadedSUT()

        try await sut.service.clearForSession()
        try await sut.service.clearForSession()
        sut.repo.enqueueFetchChildren(.success(ChildFixtures.twoChildren()))
        await sut.service.loadChildren()

        #expect(sut.service.phase == .loaded)
        #expect(sut.service.children == ChildFixtures.twoChildren())
    }
}
