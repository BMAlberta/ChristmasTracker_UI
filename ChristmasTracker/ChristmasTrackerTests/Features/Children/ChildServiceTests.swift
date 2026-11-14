//
//  ChildServiceTests.swift
//  ChristmasTrackerTests
//
//  Story I3b-M2: ChildService behavior (load phases, add, delete, isMutating).
//
//  Determinism: a gated ChildRepository fake with the nextHeldCall() handshake. No sleeps, no
//  yield loops. Session safety lives in ChildServiceSessionSafetyTests.
//
//  UX1a Story U2 (named): the shared `ChildService.error` is gone. Add and delete failures are
//  only THROWN and leave `phase` (the load channel) alone; load failures are asserted through
//  `phase`. Each rewritten test is marked "REWRITTEN (UX1a U2)".
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("ChildService", .timeLimit(.minutes(1)))
@MainActor
struct ChildServiceTests {

    private struct SUT {
        let service: ChildService
        let repo: GatedChildRepository
    }

    private func makeSUT() -> SUT {
        let repo = GatedChildRepository()
        return SUT(service: ChildService(repository: repo), repo: repo)
    }

    private func newInput(displayName: String? = nil) -> CreateChildInput {
        CreateChildInput(firstName: "Eli", lastName: "Example", displayName: displayName, relationship: .guardian)
    }

    private func newChild() -> Child {
        ChildFixtures.child(id: "child-3", firstName: "Eli", lastName: "Example", displayName: nil, relationship: .guardian)
    }

    private func loaded(_ children: [Child] = ChildFixtures.twoChildren()) async -> SUT {
        let sut = makeSUT()
        sut.repo.enqueueFetchChildren(.success(children))
        await sut.service.loadChildren()
        return sut
    }

    // MARK: - Initial state

    // REWRITTEN (UX1a U2): "no error" is now "phase is idle (no failed load)".
    @Test("a new service is idle with no children, no failed load and not mutating")
    func initialState() {
        let sut = makeSUT()

        #expect(sut.service.phase == .idle)
        #expect(sut.service.children.isEmpty)
        #expect(sut.service.isMutating == false)
        #expect(sut.repo.fetchChildrenCount == 0)
    }

    // MARK: - loadChildren

    @Test("loadChildren goes idle, loading, loaded and exposes the children in order")
    func loadPhases() async {
        let sut = makeSUT()
        sut.repo.enqueueFetchChildren(.success(ChildFixtures.twoChildren()), held: true)
        #expect(sut.service.phase == .idle)

        let task = Task { await sut.service.loadChildren() }
        await sut.repo.gate.nextHeldCall()

        #expect(sut.service.phase == .loading)
        #expect(sut.service.isMutating == false, "a load is not a mutation")

        sut.repo.gate.releaseAll()
        await task.value

        #expect(sut.service.phase == .loaded)
        #expect(sut.service.children == ChildFixtures.twoChildren())
    }

    @Test("loadChildren with no children is loaded and empty")
    func loadEmpty() async {
        let sut = await loaded([])

        #expect(sut.service.phase == .loaded)
        #expect(sut.service.children.isEmpty)
    }

    @Test("loadChildren failing is failed with that error and no children", arguments: [
        ChildError.network, .server, .unauthorized, .forbidden, .invalidResponse, .rateLimited(retryAfter: 3)
    ])
    func loadFailure(error: ChildError) async {
        let sut = makeSUT()
        sut.repo.enqueueFetchChildren(.failure(error))

        await sut.service.loadChildren()

        #expect(sut.service.phase == .failed(error))
        #expect(sut.service.children.isEmpty)
    }

    @Test("a failed reload keeps the previous children out: phase failed, children empty")
    func failedReloadClearsChildren() async {
        let sut = await loaded()
        sut.repo.enqueueFetchChildren(.failure(ChildError.network))

        await sut.service.loadChildren()

        #expect(sut.service.phase == .failed(.network))
        #expect(sut.service.children.isEmpty)
    }

    @Test("a reload replaces the children")
    func reloadReplaces() async {
        let sut = await loaded()
        let replacement = [ChildFixtures.child(id: "child-9", firstName: "Zoe", lastName: "Zed")]
        sut.repo.enqueueFetchChildren(.success(replacement))

        await sut.service.loadChildren()

        #expect(sut.service.phase == .loaded)
        #expect(sut.service.children == replacement)
    }

    @Test("an error that is not a ChildError still ends the load as failed with no children")
    func loadUnknownErrorFails() async {
        let sut = makeSUT()
        sut.repo.enqueueFetchChildren(.failure(ConfigurationError.clientUnavailable))

        await sut.service.loadChildren()

        guard case .failed = sut.service.phase else {
            Issue.record("expected phase .failed, got \(sut.service.phase)")
            return
        }
        #expect(sut.service.children.isEmpty)
    }

    // MARK: - addChild

    @Test("addChild appends the returned child and the phase stays loaded")
    func addAppends() async throws {
        let sut = await loaded()
        sut.repo.enqueueCreateChild(.success(newChild()))

        try await sut.service.addChild(newInput())

        #expect(sut.service.children == ChildFixtures.twoChildren() + [newChild()])
        #expect(sut.service.phase == .loaded)
        #expect(sut.repo.createdInputs == [newInput()])
        #expect(sut.repo.fetchChildrenCount == 1, "add does not refetch")
        #expect(sut.service.isMutating == false)
    }

    // REWRITTEN (UX1a U2): the typed error is thrown; nothing is stored, the load channel is untouched.
    @Test("addChild failing throws the typed error, appends nothing and leaves the load phase alone", arguments: [
        ChildError.validation(message: "First name is required"), .rateLimited(retryAfter: 3), .network, .forbidden, .server
    ])
    func addFailure(error: ChildError) async {
        let sut = await loaded()
        sut.repo.enqueueCreateChild(.failure(error))

        await #expect(throws: error) {
            try await sut.service.addChild(newInput())
        }

        #expect(sut.service.children == ChildFixtures.twoChildren())
        #expect(sut.service.phase == .loaded, "a mutation failure never becomes a load failure")
        #expect(sut.service.isMutating == false)
    }

    // MARK: - deleteChild

    @Test("deleteChild removes the child on success")
    func deleteRemoves() async throws {
        let sut = await loaded()
        sut.repo.enqueueDeleteChild(.success(()))

        try await sut.service.deleteChild(id: "child-1")

        #expect(sut.service.children.map(\.id) == ["child-2"])
        #expect(sut.repo.deletedIds == ["child-1"])
        #expect(sut.service.phase == .loaded)
        #expect(sut.service.isMutating == false)
    }

    @Test("deleteChild failing with childNotFound removes the child locally and rethrows")
    func deleteChildNotFoundRemovesLocally() async {
        let sut = await loaded()
        sut.repo.enqueueDeleteChild(.failure(ChildError.childNotFound))

        await #expect(throws: ChildError.childNotFound) {
            try await sut.service.deleteChild(id: "child-1")
        }

        #expect(sut.service.children.map(\.id) == ["child-2"])
        #expect(sut.service.isMutating == false)
    }

    @Test("deleteChild failing with childHasLists keeps the child and rethrows")
    func deleteChildHasListsKeepsChild() async {
        let sut = await loaded()
        sut.repo.enqueueDeleteChild(.failure(ChildError.childHasLists))

        await #expect(throws: ChildError.childHasLists) {
            try await sut.service.deleteChild(id: "child-1")
        }

        #expect(sut.service.children == ChildFixtures.twoChildren())
        #expect(sut.service.phase == .loaded, "the thrown error is not a load failure")
        #expect(sut.service.isMutating == false)
    }

    @Test("deleteChild failing with any other error keeps the child and rethrows", arguments: [
        ChildError.network, .server, .forbidden, .unauthorized, .rateLimited(retryAfter: 3),
        .validation(message: "Cannot delete this child")
    ])
    func deleteOtherFailureKeepsChild(error: ChildError) async {
        let sut = await loaded()
        sut.repo.enqueueDeleteChild(.failure(error))

        await #expect(throws: error) {
            try await sut.service.deleteChild(id: "child-1")
        }

        #expect(sut.service.children == ChildFixtures.twoChildren())
        #expect(sut.service.phase == .loaded, "the thrown error is not a load failure")
    }

    @Test("deleteChild removes only the matching child, keeping the order of the rest")
    func deleteKeepsOrder() async throws {
        let three = ChildFixtures.twoChildren() + [newChild()]
        let sut = await loaded(three)
        sut.repo.enqueueDeleteChild(.success(()))

        try await sut.service.deleteChild(id: "child-2")

        #expect(sut.service.children.map(\.id) == ["child-1", "child-3"])
    }

    // MARK: - isMutating

    @Test("isMutating is true only while addChild runs")
    func isMutatingDuringAdd() async {
        let sut = await loaded()
        sut.repo.enqueueCreateChild(.success(newChild()), held: true)
        let task = Task { _ = try? await sut.service.addChild(newInput()) }
        await sut.repo.gate.nextHeldCall()

        #expect(sut.service.isMutating == true)
        #expect(sut.service.phase == .loaded)

        sut.repo.gate.releaseAll()
        await task.value

        #expect(sut.service.isMutating == false)
    }

    @Test("isMutating is true only while deleteChild runs")
    func isMutatingDuringDelete() async {
        let sut = await loaded()
        sut.repo.enqueueDeleteChild(.success(()), held: true)
        let task = Task { _ = try? await sut.service.deleteChild(id: "child-1") }
        await sut.repo.gate.nextHeldCall()

        #expect(sut.service.isMutating == true)

        sut.repo.gate.releaseAll()
        await task.value

        #expect(sut.service.isMutating == false)
    }
}
