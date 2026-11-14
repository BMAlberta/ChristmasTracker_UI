//
//  ChildServiceLoadFailureTests.swift
//  ChristmasTrackerTests
//
//  UX1a Story U2: ChildService has no shared `error` any more. `phase` is the Children load failure
//  channel (.failed(ChildError)); `clearLoadFailure()` turns a .failed phase into .idle (the Children
//  screen calls it on disappear) and does nothing otherwise, so it never clears a loaded list. The add
//  and delete failures are only thrown and never reach `phase`.
//
//  Determinism: a gated ChildRepository fake with the nextHeldCall() handshake. No sleeps, no yield loops.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("ChildService load failure", .timeLimit(.minutes(1)))
@MainActor
struct ChildServiceLoadFailureTests {

    private struct SUT {
        let service: ChildService
        let repo: GatedChildRepository
    }

    private func makeSUT() -> SUT {
        let repo = GatedChildRepository()
        return SUT(service: ChildService(repository: repo), repo: repo)
    }

    private func newInput() -> CreateChildInput {
        CreateChildInput(firstName: "Eli", lastName: "Example", displayName: nil, relationship: .guardian)
    }

    // MARK: - clearLoadFailure

    @Test("clearLoadFailure turns a failed phase into idle", arguments: [
        ChildError.network, .server, .forbidden, .unauthorized, .rateLimited(retryAfter: 3)
    ])
    func failedBecomesIdle(error: ChildError) async {
        let sut = makeSUT()
        sut.repo.enqueueFetchChildren(.failure(error))
        await sut.service.loadChildren()
        #expect(sut.service.phase == .failed(error), "precondition")

        sut.service.clearLoadFailure()

        #expect(sut.service.phase == .idle)
        #expect(sut.service.children.isEmpty)
    }

    @Test("clearLoadFailure does not touch a loaded list")
    func loadedListIsUntouched() async {
        let sut = makeSUT()
        sut.repo.enqueueFetchChildren(.success(ChildFixtures.twoChildren()))
        await sut.service.loadChildren()

        sut.service.clearLoadFailure()

        #expect(sut.service.phase == .loaded)
        #expect(sut.service.children == ChildFixtures.twoChildren())
    }

    @Test("clearLoadFailure on a loaded EMPTY list keeps it loaded (an empty list is not a failure)")
    func loadedEmptyIsUntouched() async {
        let sut = makeSUT()
        sut.repo.enqueueFetchChildren(.success([]))
        await sut.service.loadChildren()

        sut.service.clearLoadFailure()

        #expect(sut.service.phase == .loaded)
        #expect(sut.service.children.isEmpty)
    }

    @Test("clearLoadFailure on a new service stays idle")
    func idleStaysIdle() {
        let sut = makeSUT()

        sut.service.clearLoadFailure()

        #expect(sut.service.phase == .idle)
    }

    @Test("clearLoadFailure while a load is in flight leaves the phase loading")
    func loadingIsUntouched() async {
        let sut = makeSUT()
        sut.repo.enqueueFetchChildren(.success(ChildFixtures.twoChildren()), held: true)
        let task = Task { await sut.service.loadChildren() }
        await sut.repo.gate.nextHeldCall()

        sut.service.clearLoadFailure()

        #expect(sut.service.phase == .loading)
        sut.repo.gate.releaseAll()
        await task.value
        #expect(sut.service.phase == .loaded)
        #expect(sut.service.children == ChildFixtures.twoChildren())
    }

    @Test("after clearLoadFailure the next load runs normally")
    func nextLoadAfterClear() async {
        let sut = makeSUT()
        sut.repo.enqueueFetchChildren(.failure(ChildError.network))
        await sut.service.loadChildren()
        sut.service.clearLoadFailure()
        sut.repo.enqueueFetchChildren(.success(ChildFixtures.twoChildren()))

        await sut.service.loadChildren()

        #expect(sut.service.phase == .loaded)
        #expect(sut.service.children == ChildFixtures.twoChildren())
    }

    @Test("clearLoadFailure is harmless when called twice")
    func clearTwice() async {
        let sut = makeSUT()
        sut.repo.enqueueFetchChildren(.failure(ChildError.server))
        await sut.service.loadChildren()

        sut.service.clearLoadFailure()
        sut.service.clearLoadFailure()

        #expect(sut.service.phase == .idle)
    }

    // MARK: - The load channel is set only by loads

    @Test("a failed load sets the failed phase and a successful load of the same service clears it")
    func successfulLoadClearsFailedPhase() async {
        let sut = makeSUT()
        sut.repo.enqueueFetchChildren(.failure(ChildError.network))
        await sut.service.loadChildren()
        #expect(sut.service.phase == .failed(.network), "precondition")
        sut.repo.enqueueFetchChildren(.success(ChildFixtures.twoChildren()))

        await sut.service.loadChildren()

        #expect(sut.service.phase == .loaded)
    }

    @Test("a failed addChild throws and leaves the loaded phase and the children alone", arguments: [
        ChildError.network, .server, .forbidden, .rateLimited(retryAfter: 3), .validation(message: "First name is required")
    ])
    func failedAddLeavesLoadChannel(error: ChildError) async {
        let sut = makeSUT()
        sut.repo.enqueueFetchChildren(.success(ChildFixtures.twoChildren()))
        await sut.service.loadChildren()
        sut.repo.enqueueCreateChild(.failure(error))

        await #expect(throws: error) {
            try await sut.service.addChild(newInput())
        }

        #expect(sut.service.phase == .loaded, "an add failure is never a load failure")
        #expect(sut.service.children == ChildFixtures.twoChildren())
    }

    @Test("a failed deleteChild throws and leaves the loaded phase alone", arguments: [
        ChildError.network, .server, .forbidden, .childHasLists, .rateLimited(retryAfter: 3)
    ])
    func failedDeleteLeavesLoadChannel(error: ChildError) async {
        let sut = makeSUT()
        sut.repo.enqueueFetchChildren(.success(ChildFixtures.twoChildren()))
        await sut.service.loadChildren()
        sut.repo.enqueueDeleteChild(.failure(error))

        await #expect(throws: error) {
            try await sut.service.deleteChild(id: "child-1")
        }

        #expect(sut.service.phase == .loaded, "a delete failure is never a load failure")
    }

    @Test("clearLoadFailure after a failed mutation does not change the loaded phase")
    func clearAfterFailedMutationKeepsLoaded() async {
        let sut = makeSUT()
        sut.repo.enqueueFetchChildren(.success(ChildFixtures.twoChildren()))
        await sut.service.loadChildren()
        sut.repo.enqueueCreateChild(.failure(ChildError.server))
        _ = try? await sut.service.addChild(newInput())

        sut.service.clearLoadFailure()

        #expect(sut.service.phase == .loaded)
        #expect(sut.service.children == ChildFixtures.twoChildren())
    }

    // MARK: - Teardown

    @Test("clearForSession returns a failed phase to idle")
    func clearForSessionClearsFailedPhase() async throws {
        let sut = makeSUT()
        sut.repo.enqueueFetchChildren(.failure(ChildError.network))
        await sut.service.loadChildren()

        try await sut.service.clearForSession()

        #expect(sut.service.phase == .idle)
    }
}
