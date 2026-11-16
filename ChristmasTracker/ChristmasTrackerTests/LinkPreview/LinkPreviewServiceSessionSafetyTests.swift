//
//  LinkPreviewServiceSessionSafetyTests.swift
//  ChristmasTrackerTests
//
//  IMG1-P1: LinkPreviewService is session-safe like StatsService.
//
//  Rules under test:
//   - a result (value or failure) that arrives after clearForSession or SessionManager.teardown is
//     dropped: the call returns nil and nothing is raised;
//   - teardown cancels the in-flight repository task;
//   - cancelling the calling task returns nil even when the repository returns a value late;
//   - the generation changes on every clear and at no other time;
//   - a call after teardown works normally in the new session.
//
//  Determinism: gated fake with the nextHeldCall() handshake. No sleeps, no yield loops.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("LinkPreviewService session safety", .timeLimit(.minutes(1)))
@MainActor
struct LinkPreviewServiceSessionSafetyTests {

    private static let page = "https://shop.example.test/p/1"
    private static let goodImage = "https://images.example.test/a.jpg"
    nonisolated static let reasons: [TeardownReason] = [.userLogout, .sessionExpired, .forcedUpdate, .lockFallback]

    private struct SUT {
        let service: LinkPreviewService
        let loader: GatedLinkPreviewLoader
        let manager: SessionManager
    }

    private func makeSUT(honorsCancellation: Bool = false) async -> SUT {
        let loader = GatedLinkPreviewLoader()
        loader.gate.honorsCancellation = honorsCancellation
        let service = LinkPreviewService(repository: loader)
        let manager = SessionManager(initialClearables: [])
        await manager.register(service)
        return SUT(service: service, loader: loader, manager: manager)
    }

    private func start(_ service: LinkPreviewService) -> Task<String?, Never> {
        Task { @MainActor in await service.imageUrl(for: Self.page) }
    }

    // MARK: Teardown during a call

    @Test("a value that arrives after teardown is dropped", arguments: [false, true])
    func valueAfterTeardown(honorsCancellation: Bool) async {
        let sut = await makeSUT(honorsCancellation: honorsCancellation)
        sut.loader.enqueue(Self.goodImage, held: true)
        let task = start(sut.service)
        await sut.loader.gate.nextHeldCall()
        let before = sut.service.sessionGeneration

        await sut.manager.teardown(reason: .userLogout)
        sut.loader.gate.releaseAll()
        let result = await task.value

        #expect(result == nil, "a stale value must not be returned")
        #expect(sut.service.sessionGeneration > before)
    }

    @Test("a failure that arrives after teardown is dropped", arguments: [false, true])
    func failureAfterTeardown(honorsCancellation: Bool) async {
        let sut = await makeSUT(honorsCancellation: honorsCancellation)
        sut.loader.enqueueFailure(URLError(.timedOut), held: true)
        let task = start(sut.service)
        await sut.loader.gate.nextHeldCall()

        await sut.manager.teardown(reason: .userLogout)
        sut.loader.gate.releaseAll()
        let result = await task.value

        #expect(result == nil)
    }

    @Test("clearForSession directly drops an in-flight call", arguments: [false, true])
    func clearForSessionDropsTheCall(honorsCancellation: Bool) async throws {
        let sut = await makeSUT(honorsCancellation: honorsCancellation)
        sut.loader.enqueue(Self.goodImage, held: true)
        let task = start(sut.service)
        await sut.loader.gate.nextHeldCall()

        try await sut.service.clearForSession()
        sut.loader.gate.releaseAll()

        #expect(await task.value == nil)
    }

    @Test("teardown for every reason drops an in-flight call", arguments: reasons)
    func everyTeardownReason(reason: TeardownReason) async {
        let sut = await makeSUT()
        sut.loader.enqueue(Self.goodImage, held: true)
        let task = start(sut.service)
        await sut.loader.gate.nextHeldCall()

        await sut.manager.teardown(reason: reason)
        sut.loader.gate.releaseAll()

        #expect(await task.value == nil)
    }

    @Test("teardown cancels the in-flight repository task: a loader that honors cancellation ends without any release")
    func teardownCancelsTheInFlightTask() async {
        let sut = await makeSUT(honorsCancellation: true)
        sut.loader.enqueue(Self.goodImage, held: true)
        let task = start(sut.service)
        await sut.loader.gate.nextHeldCall()

        await sut.manager.teardown(reason: .userLogout)
        // No release: the call can only end because the service cancelled its task.
        let result = await task.value

        #expect(result == nil)
        #expect(sut.loader.cancelledCallCount == 1)
    }

    @Test("teardown drops every in-flight call at once")
    func teardownDropsAllInFlight() async {
        let sut = await makeSUT()
        sut.loader.enqueue(Self.goodImage, held: true)
        sut.loader.enqueue(Self.goodImage, held: true)
        let first = start(sut.service)
        await sut.loader.gate.nextHeldCall()
        let second = start(sut.service)
        await sut.loader.gate.nextHeldCall()

        await sut.manager.teardown(reason: .userLogout)
        sut.loader.gate.releaseAll()

        #expect(await first.value == nil)
        #expect(await second.value == nil)
    }

    // MARK: Generation

    @Test("every clear changes the generation; calls do not")
    func clearChangesGeneration() async {
        let sut = await makeSUT()
        let first = sut.service.sessionGeneration

        await sut.manager.teardown(reason: .userLogout)
        let second = sut.service.sessionGeneration
        await sut.manager.teardown(reason: .userLogout)
        let third = sut.service.sessionGeneration

        #expect(second > first)
        #expect(third > second)
    }

    @Test("clearForSession on an idle service is harmless and repeatable")
    func clearIdle() async throws {
        let sut = await makeSUT()

        try await sut.service.clearForSession()
        try await sut.service.clearForSession()
        sut.loader.enqueue(Self.goodImage)

        #expect(await sut.service.imageUrl(for: Self.page) == Self.goodImage)
    }

    // MARK: User switch

    @Test("user switch: A's late value never reaches B and B's call works")
    func userSwitchLateValue() async {
        let sut = await makeSUT()
        sut.loader.enqueue("https://images.example.test/user-a.jpg", held: true)
        sut.loader.enqueue("https://images.example.test/user-b.jpg")
        let userA = start(sut.service)
        await sut.loader.gate.nextHeldCall()

        await sut.manager.teardown(reason: .userLogout)
        let userB = await sut.service.imageUrl(for: Self.page)
        sut.loader.gate.releaseAll()

        #expect(userB == "https://images.example.test/user-b.jpg")
        #expect(await userA.value == nil)
    }

    @Test("a call after teardown works normally in the new session")
    func callAfterTeardown() async {
        let sut = await makeSUT()
        await sut.manager.teardown(reason: .userLogout)
        sut.loader.enqueue(Self.goodImage)

        #expect(await sut.service.imageUrl(for: Self.page) == Self.goodImage)
    }

    // MARK: Caller cancellation

    @Test("cancelling the calling task returns nil even if the repository returns a value late",
          arguments: [false, true])
    func cancellingTheCaller(honorsCancellation: Bool) async {
        let sut = await makeSUT(honorsCancellation: honorsCancellation)
        sut.loader.enqueue(Self.goodImage, held: true)
        let task = start(sut.service)
        await sut.loader.gate.nextHeldCall()
        let before = sut.service.sessionGeneration

        task.cancel()
        sut.loader.gate.releaseAll()
        let result = await task.value

        #expect(result == nil)
        #expect(sut.service.sessionGeneration == before, "caller cancellation is not a session end")
    }

    @Test("a cancelled call does not break the next call")
    func nextCallAfterCancellation() async {
        let sut = await makeSUT(honorsCancellation: true)
        sut.loader.enqueue(Self.goodImage, held: true)
        let task = start(sut.service)
        await sut.loader.gate.nextHeldCall()
        task.cancel()
        sut.loader.gate.releaseAll()
        _ = await task.value
        sut.loader.enqueue("https://images.example.test/second.jpg")

        #expect(await sut.service.imageUrl(for: Self.page) == "https://images.example.test/second.jpg")
    }

    // MARK: Registration

    @Test("SessionManager.teardown clears a service registered as a clearable (generation moves)",
          arguments: reasons)
    func registeredServiceIsCleared(reason: TeardownReason) async {
        let sut = await makeSUT()
        let before = sut.service.sessionGeneration

        await sut.manager.teardown(reason: reason)

        #expect(sut.service.sessionGeneration != before)
    }
}
