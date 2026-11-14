//
//  ChildDeletionFlowSessionTests.swift
//  ChristmasTrackerTests
//
//  Story I3d-D2: cancellation and user switches during ChildDeletionFlow. A cancelled caller or a
//  cleared session (clearForSession on either service) stops the flow between steps: result nil,
//  no further repository calls, no child delete, nothing written, no shared error.
//
//  Determinism: gated fakes with the nextHeldCall() handshake. No sleeps, no yield loops.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("ChildDeletionFlow cancellation and session", .timeLimit(.minutes(1)))
@MainActor
struct ChildDeletionFlowSessionTests {

    private typealias H = ChildDeletionFlowHarness
    private let childId = ChildDeletionFlowHarness.childId

    // MARK: - Cancellation

    @Test("plan throws CancellationError when the calling task is cancelled during the fetch")
    func planCancelled() async {
        let sut = await H.make(honorsCancellation: true)
        sut.listRepo.enqueueFetchLists(.success([H.childList("list-a")]), held: true)
        let task = Task { () -> Bool in
            do {
                _ = try await sut.flow.plan(childId: childId)
                return false
            } catch is CancellationError {
                return true
            } catch {
                return false
            }
        }
        await sut.listRepo.nextHeldCall()

        task.cancel()
        sut.listRepo.releaseAll()
        let threwCancellation = await task.value

        #expect(threwCancellation)
        #expect(sut.sharedErrorsAreNil)
        #expect(sut.listService.lists.isEmpty)
    }

    @Test("plan throws CancellationError when the list session is cleared during the fetch", arguments: [false, true])
    func planSessionCleared(honorsCancellation: Bool) async throws {
        let sut = await H.make(honorsCancellation: honorsCancellation)
        sut.listRepo.enqueueFetchLists(.success([H.childList("list-a")]), held: true)
        let task = Task { () -> Bool in
            do {
                _ = try await sut.flow.plan(childId: childId)
                return false
            } catch is CancellationError {
                return true
            } catch {
                return false
            }
        }
        await sut.listRepo.nextHeldCall()

        try await sut.listService.clearForSession()
        sut.listRepo.releaseAll()
        let threwCancellation = await task.value

        #expect(threwCancellation)
        #expect(sut.listService.lists.isEmpty)
        #expect(sut.sharedErrorsAreNil)
    }

    @Test("run returns nil when cancelled while it plans, and deletes nothing")
    func runCancelledDuringPlan() async {
        let sut = await H.make(honorsCancellation: true)
        sut.listRepo.enqueueFetchLists(.success([]), held: true)
        sut.childRepo.enqueueDeleteChild(.success(()))   // must never be consumed
        let task = Task { await sut.flow.run(childId: childId) }
        await sut.listRepo.nextHeldCall()

        task.cancel()
        sut.listRepo.releaseAll()
        let result = await task.value

        #expect(result == nil)
        #expect(sut.childRepo.deleteChildCount == 0)
        #expect(sut.listRepo.deleteListCount == 0)
        #expect(sut.sharedErrorsAreNil)
    }

    @Test("cancelling during the first archive returns nil and starts nothing else")
    func cancelledDuringArchive() async {
        let sut = await H.make(honorsCancellation: true)
        sut.listRepo.enqueueDeleteList(.success(()), held: true)
        sut.listRepo.enqueueDeleteList(.success(()))   // must never be consumed
        sut.childRepo.enqueueDeleteChild(.success(()))   // must never be consumed
        let task = Task {
            await sut.flow.execute(childId: childId, plan: .archiveThenDelete(listIds: ["list-a", "list-b"]))
        }
        await sut.listRepo.nextHeldCall()

        task.cancel()
        sut.listRepo.releaseAll()
        let result = await task.value

        #expect(result == nil)
        #expect(sut.listRepo.deleteListCount == 1, "the second archive must not start")
        #expect(sut.childRepo.deleteChildCount == 0)
        #expect(sut.childService.children.count == 2)
        #expect(sut.sharedErrorsAreNil)
        #expect(sut.listService.isMutating == false)
    }

    @Test("cancelling during the child delete returns nil and leaves the child in the service")
    func cancelledDuringChildDelete() async {
        let sut = await H.make(honorsCancellation: true)
        sut.childRepo.enqueueDeleteChild(.success(()), held: true)
        let task = Task { await sut.flow.execute(childId: childId, plan: .deleteNow) }
        await sut.childRepo.gate.nextHeldCall()

        task.cancel()
        sut.childRepo.gate.releaseAll()
        let result = await task.value

        #expect(result == nil)
        #expect(sut.childService.children.count == 2)
        #expect(sut.sharedErrorsAreNil)
        #expect(sut.childService.isMutating == false)
    }

    // MARK: - User switch on the list service

    @Test("the list session cleared during an archive stops the flow: nil, no reload, no child delete", arguments: [false, true])
    func listSessionClearedDuringArchive(honorsCancellation: Bool) async throws {
        let sut = await H.make(honorsCancellation: honorsCancellation)
        sut.listRepo.enqueueDeleteList(.success(()), held: true)
        sut.listRepo.enqueueDeleteList(.success(()))   // must never be consumed
        sut.listRepo.enqueueFetchLists(.success([H.archivedChildList("list-a")]))   // must never be consumed
        sut.childRepo.enqueueDeleteChild(.success(()))   // must never be consumed
        let task = Task {
            await sut.flow.execute(childId: childId, plan: .archiveThenDelete(listIds: ["list-a", "list-b"]))
        }
        await sut.listRepo.nextHeldCall()

        try await sut.listService.clearForSession()
        sut.listRepo.releaseAll()
        let result = await task.value

        #expect(result == nil)
        #expect(sut.listRepo.deleteListCount == 1)
        #expect(sut.listRepo.fetchListsCount == 0)
        #expect(sut.childRepo.deleteChildCount == 0)
        #expect(sut.listService.lists.isEmpty)
        #expect(sut.childService.children.count == 2, "the other service is not written to either")
        #expect(sut.sharedErrorsAreNil)
        let cached = await sut.store.getLists()
        #expect(cached.isEmpty)
    }

    @Test("the list session cleared during run's plan fetch returns nil and deletes nothing", arguments: [false, true])
    func listSessionClearedDuringRunPlan(honorsCancellation: Bool) async throws {
        let sut = await H.make(honorsCancellation: honorsCancellation)
        sut.listRepo.enqueueFetchLists(.success([]), held: true)
        sut.childRepo.enqueueDeleteChild(.success(()))   // must never be consumed
        let task = Task { await sut.flow.run(childId: childId) }
        await sut.listRepo.nextHeldCall()

        try await sut.listService.clearForSession()
        sut.listRepo.releaseAll()
        let result = await task.value

        #expect(result == nil)
        #expect(sut.childRepo.deleteChildCount == 0)
        #expect(sut.listService.lists.isEmpty)
        #expect(sut.sharedErrorsAreNil)
    }

    // MARK: - User switch on the child service

    @Test("the child session cleared during the child delete returns nil and writes nothing", arguments: [false, true])
    func childSessionClearedDuringChildDelete(honorsCancellation: Bool) async throws {
        let sut = await H.make(honorsCancellation: honorsCancellation)
        sut.childRepo.enqueueDeleteChild(.success(()), held: true)
        let task = Task { await sut.flow.execute(childId: childId, plan: .deleteNow) }
        await sut.childRepo.gate.nextHeldCall()

        try await sut.childService.clearForSession()
        sut.childRepo.gate.releaseAll()
        let result = await task.value

        #expect(result == nil)
        #expect(sut.childService.children.isEmpty)
        #expect(sut.sharedErrorsAreNil)
        #expect(sut.childService.isMutating == false)
    }

    @Test("the child session cleared during the archives stops the flow before the child delete", arguments: [false, true])
    func childSessionClearedDuringArchive(honorsCancellation: Bool) async throws {
        let sut = await H.make(honorsCancellation: honorsCancellation)
        sut.listRepo.enqueueDeleteList(.success(()), held: true)
        sut.listRepo.enqueueFetchLists(.success([H.archivedChildList("list-a")]))
        sut.childRepo.enqueueDeleteChild(.success(()))   // must never be consumed
        let task = Task {
            await sut.flow.execute(childId: childId, plan: .archiveThenDelete(listIds: ["list-a"]))
        }
        await sut.listRepo.nextHeldCall()

        try await sut.childService.clearForSession()
        sut.listRepo.releaseAll()
        let result = await task.value

        #expect(result == nil)
        #expect(sut.childRepo.deleteChildCount == 0, "the user switched: the new user's child list must not get a delete")
        #expect(sut.childService.children.isEmpty)
        #expect(sut.sharedErrorsAreNil)
    }
}
