//
//  ChildDeletionFlowTests.swift
//  ChristmasTrackerTests
//
//  Story I3d-D2: ChildDeletionFlow scenarios through the real ChildService and ListService over
//  gated fakes: plan (forced fetch), execute for every plan, partial failure, Try Again through
//  run(childId:), 404 handling, and child-delete failures. Cancellation and user switches live in
//  ChildDeletionFlowSessionTests.
//
//  Determinism: gated fakes with the nextHeldCall() handshake. No sleeps, no yield loops.
//

import Foundation
import Testing
@testable import ChristmasTracker

/// A list failure and the child error the flow must report for it.
nonisolated struct ListToChildErrorCase: Sendable, CustomTestStringConvertible {
    let list: ListError
    let child: ChildError

    var testDescription: String { "\(list) -> \(child)" }

    static let all: [ListToChildErrorCase] = [
        ListToChildErrorCase(list: .forbidden, child: .forbidden),
        ListToChildErrorCase(list: .unauthorized, child: .unauthorized),
        ListToChildErrorCase(list: .rateLimited(retryAfter: 7), child: .rateLimited(retryAfter: 7)),
        ListToChildErrorCase(list: .network, child: .network),
        ListToChildErrorCase(list: .invalidResponse, child: .invalidResponse),
        ListToChildErrorCase(list: .server, child: .server),
        ListToChildErrorCase(list: .sessionEnded, child: .sessionEnded),
        ListToChildErrorCase(list: .archivedReadOnly, child: .server),
        ListToChildErrorCase(list: .validation(message: "bad"), child: .server),
        ListToChildErrorCase(list: .alreadyMember, child: .server)
    ]
}

@Suite("ChildDeletionFlow", .timeLimit(.minutes(1)))
@MainActor
struct ChildDeletionFlowTests {

    private typealias H = ChildDeletionFlowHarness
    private let childId = ChildDeletionFlowHarness.childId

    // MARK: - plan

    @Test("plan fetches the lists afresh every time, never from the cache, and applies the plan")
    func planUsesForcedFetch() async throws {
        let sut = await H.make()
        await sut.store.setLists([H.childList("stale")])
        sut.listRepo.enqueueFetchLists(.success([H.childList("list-a"), H.childList("list-b")]))
        sut.listRepo.enqueueFetchLists(.success([]))

        let first = try await sut.flow.plan(childId: childId)
        let second = try await sut.flow.plan(childId: childId)

        #expect(first == .archiveThenDelete(listIds: ["list-a", "list-b"]))
        #expect(second == .deleteNow)
        #expect(sut.listRepo.fetchListsCount == 2)
        #expect(sut.sharedErrorsAreNil)
    }

    @Test("plan is blocked when an active list of the child cannot be deleted by the user")
    func planBlocked() async throws {
        let sut = await H.make()
        sut.listRepo.enqueueFetchLists(.success([H.childList("list-a"), H.childList("list-b", canDelete: false)]))

        let plan = try await sut.flow.plan(childId: childId)

        #expect(plan == .blocked)
    }

    @Test("plan ignores archived lists of the child")
    func planIgnoresArchived() async throws {
        let sut = await H.make()
        sut.listRepo.enqueueFetchLists(.success([H.archivedChildList("list-a")]))

        let plan = try await sut.flow.plan(childId: childId)

        #expect(plan == .deleteNow)
    }

    @Test("plan throws the mapped ChildError when the fetch fails and publishes no shared error", arguments: ListToChildErrorCase.all)
    func planFailure(row: ListToChildErrorCase) async {
        let sut = await H.make()
        sut.listRepo.enqueueFetchLists(.failure(row.list))

        await #expect(throws: row.child) {
            _ = try await sut.flow.plan(childId: childId)
        }

        #expect(sut.sharedErrorsAreNil)
        #expect(sut.childRepo.deleteChildCount == 0)
    }

    // MARK: - execute: blocked and deleteNow

    @Test("execute(.blocked) returns blocked and calls nothing")
    func executeBlocked() async {
        let sut = await H.make()

        let result = await sut.flow.execute(childId: childId, plan: .blocked)

        #expect(result == .blocked)
        #expect(sut.listRepo.fetchListsCount == 0)
        #expect(sut.listRepo.deleteListCount == 0)
        #expect(sut.childRepo.deleteChildCount == 0)
        #expect(sut.childService.children.count == 2)
    }

    @Test("execute(.deleteNow) deletes the child and archives nothing")
    func executeDeleteNow() async {
        let sut = await H.make()
        sut.childRepo.enqueueDeleteChild(.success(()))

        let result = await sut.flow.execute(childId: childId, plan: .deleteNow)

        #expect(result == .deleted)
        #expect(sut.childRepo.deletedIds == [childId])
        #expect(sut.listRepo.deleteListCount == 0)
        #expect(sut.childService.children.contains(where: { $0.id == childId }) == false)
        #expect(sut.sharedErrorsAreNil)
    }

    // MARK: - execute: archiveThenDelete

    @Test("execute(.archiveThenDelete) archives in order, reloads once, then deletes the child")
    func executeArchiveThenDelete() async {
        let sut = await H.make()
        sut.listRepo.enqueueDeleteList(.success(()), held: true)
        sut.listRepo.enqueueDeleteList(.success(()), held: true)
        sut.listRepo.enqueueFetchLists(.success([H.archivedChildList("list-b"), H.archivedChildList("list-a")]))
        sut.childRepo.enqueueDeleteChild(.success(()), held: true)
        let plan = ChildDeletionPlan.archiveThenDelete(listIds: ["list-b", "list-a"])
        let task = Task { await sut.flow.execute(childId: childId, plan: plan) }

        let first = await sut.listRepo.nextHeldCall()
        #expect(first == .deleteList("list-b"))
        #expect(sut.childRepo.deleteChildCount == 0)
        sut.listRepo.releaseNext()
        let second = await sut.listRepo.nextHeldCall()
        #expect(second == .deleteList("list-a"))
        #expect(sut.childRepo.deleteChildCount == 0)
        sut.listRepo.releaseNext()
        let childCall = await sut.childRepo.gate.nextHeldCall()
        #expect(childCall == .deleteChild(childId))
        #expect(sut.listRepo.deleteListCount == 2, "the child is deleted only after every list was archived")
        #expect(sut.listRepo.fetchListsCount == 1, "the lists were reloaded before the child delete")
        sut.childRepo.gate.releaseNext()
        let result = await task.value

        #expect(result == .archivedThenDeleted(count: 2))
        #expect(sut.listService.archivedLists.map(\.id) == ["list-b", "list-a"])
        #expect(sut.childService.children.contains(where: { $0.id == childId }) == false)
        #expect(sut.sharedErrorsAreNil)
    }

    @Test("a 404 on a list counts as archived and the flow finishes")
    func listNotFoundCountsAsArchived() async {
        let sut = await H.make()
        sut.listRepo.enqueueDeleteList(.success(()))
        sut.listRepo.enqueueDeleteList(.failure(ListError.notFound))
        sut.listRepo.enqueueFetchLists(.success([H.archivedChildList("list-a")]))
        sut.childRepo.enqueueDeleteChild(.success(()))

        let result = await sut.flow.execute(childId: childId, plan: .archiveThenDelete(listIds: ["list-a", "list-b"]))

        #expect(result == .archivedThenDeleted(count: 2))
        #expect(sut.childRepo.deleteChildCount == 1)
    }

    // MARK: - execute: partial failure

    @Test("a failure on the second of three lists stops, never deletes the child and reports counts")
    func partialFailure() async {
        let sut = await H.make()
        sut.listRepo.enqueueDeleteList(.success(()))
        sut.listRepo.enqueueDeleteList(.failure(ListError.forbidden))
        sut.listRepo.enqueueDeleteList(.success(()))   // must never be consumed
        sut.listRepo.enqueueFetchLists(.success([H.archivedChildList("list-a"), H.childList("list-b"), H.childList("list-c")]))
        sut.childRepo.enqueueDeleteChild(.success(()))   // must never be consumed

        let result = await sut.flow.execute(
            childId: childId,
            plan: .archiveThenDelete(listIds: ["list-a", "list-b", "list-c"])
        )

        #expect(result == .partialFailure(archivedCount: 1, totalCount: 3, error: .forbidden))
        #expect(sut.childRepo.deleteChildCount == 0, "the child must never be deleted after an archive failure")
        #expect(sut.listRepo.deleteListCount == 2)
        #expect(sut.listRepo.fetchListsCount == 1)
        #expect(sut.childService.children.contains(where: { $0.id == childId }))
        #expect(sut.sharedErrorsAreNil)
        #expect(sut.listService.isMutating == false)
        #expect(sut.childService.isMutating == false)
    }

    @Test("a failure on the first list reports zero archived and never deletes the child")
    func partialFailureWithZeroProgress() async {
        let sut = await H.make()
        sut.listRepo.enqueueDeleteList(.failure(ListError.network))
        sut.listRepo.enqueueFetchLists(.success([H.childList("list-a"), H.childList("list-b")]))

        let result = await sut.flow.execute(childId: childId, plan: .archiveThenDelete(listIds: ["list-a", "list-b"]))

        #expect(result == .partialFailure(archivedCount: 0, totalCount: 2, error: .network))
        #expect(sut.childRepo.deleteChildCount == 0)
    }

    @Test("an archive failure is mapped to the same-named ChildError", arguments: ListToChildErrorCase.all)
    func partialFailureMapping(row: ListToChildErrorCase) async {
        let sut = await H.make()
        sut.listRepo.enqueueDeleteList(.failure(row.list))
        sut.listRepo.enqueueFetchLists(.success([H.childList("list-a")]))

        let result = await sut.flow.execute(childId: childId, plan: .archiveThenDelete(listIds: ["list-a"]))

        #expect(result == .partialFailure(archivedCount: 0, totalCount: 1, error: row.child))
        #expect(sut.childRepo.deleteChildCount == 0)
        #expect(sut.sharedErrorsAreNil)
    }

    // MARK: - run: Try Again

    @Test("Try Again after a partial failure recomputes the plan from fresh data and finishes")
    func tryAgainFinishes() async {
        let sut = await H.make()
        // First attempt: list-a is archived, list-b fails.
        sut.listRepo.enqueueDeleteList(.success(()))
        sut.listRepo.enqueueDeleteList(.failure(ListError.network))
        sut.listRepo.enqueueFetchLists(.success([H.archivedChildList("list-a"), H.childList("list-b"), H.childList("list-c")]))
        let first = await sut.flow.execute(
            childId: childId,
            plan: .archiveThenDelete(listIds: ["list-a", "list-b", "list-c"])
        )
        #expect(first == .partialFailure(archivedCount: 1, totalCount: 3, error: .network))
        #expect(sut.childRepo.deleteChildCount == 0)

        // Try Again: fresh lists, then the two remaining archives, a reload, the child delete.
        sut.listRepo.enqueueFetchLists(.success([H.archivedChildList("list-a"), H.childList("list-b"), H.childList("list-c")]))
        sut.listRepo.enqueueDeleteList(.success(()), held: true)
        sut.listRepo.enqueueDeleteList(.success(()), held: true)
        sut.listRepo.enqueueFetchLists(.success([
            H.archivedChildList("list-a"), H.archivedChildList("list-b"), H.archivedChildList("list-c")
        ]))
        sut.childRepo.enqueueDeleteChild(.success(()))
        let task = Task { await sut.flow.run(childId: childId) }

        let one = await sut.listRepo.nextHeldCall()
        #expect(one == .deleteList("list-b"), "the already archived list-a must be skipped")
        sut.listRepo.releaseNext()
        let two = await sut.listRepo.nextHeldCall()
        #expect(two == .deleteList("list-c"))
        sut.listRepo.releaseNext()
        let second = await task.value

        #expect(second == .archivedThenDeleted(count: 2))
        #expect(sut.listRepo.deleteListCount == 4, "two in the first attempt, two in the retry; list-a is never sent again")
        #expect(sut.listRepo.fetchListsCount == 3, "one reload after the first attempt, one fresh plan fetch and one reload in the retry")
        #expect(sut.childRepo.deletedIds == [childId])
        #expect(sut.childService.children.contains(where: { $0.id == childId }) == false)
        #expect(sut.sharedErrorsAreNil)
    }

    @Test("run goes straight to the child delete when nothing is left to archive")
    func runWithNothingLeft() async {
        let sut = await H.make()
        sut.listRepo.enqueueFetchLists(.success([H.archivedChildList("list-a")]))
        sut.childRepo.enqueueDeleteChild(.success(()))

        let result = await sut.flow.run(childId: childId)

        #expect(result == .deleted)
        #expect(sut.listRepo.deleteListCount == 0)
        #expect(sut.childRepo.deletedIds == [childId])
    }

    @Test("run on a deletable plan archives and deletes in one go")
    func runArchiveThenDelete() async {
        let sut = await H.make()
        sut.listRepo.enqueueFetchLists(.success([H.childList("list-a"), H.childList("list-b")]))
        sut.listRepo.enqueueDeleteList(.success(()))
        sut.listRepo.enqueueDeleteList(.success(()))
        sut.listRepo.enqueueFetchLists(.success([H.archivedChildList("list-a"), H.archivedChildList("list-b")]))
        sut.childRepo.enqueueDeleteChild(.success(()))

        let result = await sut.flow.run(childId: childId)

        #expect(result == .archivedThenDeleted(count: 2))
        #expect(sut.listRepo.fetchListsCount == 2)
    }

    @Test("run returns blocked without archiving or deleting anything")
    func runBlocked() async {
        let sut = await H.make()
        sut.listRepo.enqueueFetchLists(.success([H.childList("list-a", canDelete: false)]))

        let result = await sut.flow.run(childId: childId)

        #expect(result == .blocked)
        #expect(sut.listRepo.deleteListCount == 0)
        #expect(sut.childRepo.deleteChildCount == 0)
    }

    @Test("run turns a plan failure into failed(error:) and deletes nothing", arguments: ListToChildErrorCase.all)
    func runPlanFailure(row: ListToChildErrorCase) async {
        let sut = await H.make()
        sut.listRepo.enqueueFetchLists(.failure(row.list))

        let result = await sut.flow.run(childId: childId)

        #expect(result == .failed(error: row.child))
        #expect(sut.listRepo.deleteListCount == 0)
        #expect(sut.childRepo.deleteChildCount == 0)
        #expect(sut.sharedErrorsAreNil)
    }

    // MARK: - The child delete fails

    @Test(
        "a failing child delete after the archives is reported as failed(error:), not as a partial failure",
        arguments: [ChildError.childHasLists, .server, .network, .forbidden, .unauthorized, .rateLimited(retryAfter: 3)]
    )
    func childDeleteFailsAfterArchive(error: ChildError) async {
        let sut = await H.make()
        sut.listRepo.enqueueDeleteList(.success(()))
        sut.listRepo.enqueueFetchLists(.success([H.archivedChildList("list-a")]))
        sut.childRepo.enqueueDeleteChild(.failure(error))

        let result = await sut.flow.execute(childId: childId, plan: .archiveThenDelete(listIds: ["list-a"]))

        #expect(result == .failed(error: error))
        #expect(sut.childRepo.deleteChildCount == 1)
        #expect(sut.childService.children.contains(where: { $0.id == childId }))
    }

    @Test("a 422 from a hidden active list on a deleteNow plan is failed(childHasLists)")
    func hiddenActiveList() async {
        let sut = await H.make()
        sut.childRepo.enqueueDeleteChild(.failure(ChildError.childHasLists))

        let result = await sut.flow.execute(childId: childId, plan: .deleteNow)

        #expect(result == .failed(error: .childHasLists))
        #expect(sut.childRepo.deleteChildCount == 1)
    }

    @Test("childNotFound on the child delete counts as deleted (deleteNow)")
    func childNotFoundDeleteNow() async {
        let sut = await H.make()
        sut.childRepo.enqueueDeleteChild(.failure(ChildError.childNotFound))

        let result = await sut.flow.execute(childId: childId, plan: .deleteNow)

        #expect(result == .deleted)
        #expect(sut.childService.children.contains(where: { $0.id == childId }) == false)
    }

    @Test("childNotFound on the child delete counts as deleted after the archives")
    func childNotFoundAfterArchive() async {
        let sut = await H.make()
        sut.listRepo.enqueueDeleteList(.success(()))
        sut.listRepo.enqueueFetchLists(.success([H.archivedChildList("list-a")]))
        sut.childRepo.enqueueDeleteChild(.failure(ChildError.childNotFound))

        let result = await sut.flow.execute(childId: childId, plan: .archiveThenDelete(listIds: ["list-a"]))

        #expect(result == .archivedThenDeleted(count: 1))
        #expect(sut.childService.children.contains(where: { $0.id == childId }) == false)
    }
}
