//
//  LinkPreviewServiceFallbackCancellationTests.swift
//  ChristmasTrackerTests
//
//  IMG1-P4 (decisions 4 and 11): cancellation and session end around the two steps.
//
//   - a CancellationError from the repository, a cancelled caller, or a session end before the provider
//     step: nil and the provider is NEVER called;
//   - during the provider step: the provider's cancellation is observed (caller cancel or
//     clearForSession), the result is nil, and a late value is dropped;
//   - a session end changes only the generation (no other state change), raises nothing, and the next
//     call works.
//
//  Determinism: gated fakes with the nextHeldCall() handshake. No sleeps, no yield loops.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("LinkPreviewService fallback cancellation", .timeLimit(.minutes(1)))
@MainActor
struct LinkPreviewServiceFallbackCancellationTests {

    private static let page = "https://shop.example.test/p/1"
    private static let deviceImage = "https://images.example.test/device.jpg"

    private struct SUT {
        let service: LinkPreviewService
        let loader: GatedLinkPreviewLoader
        let provider: GatedProductImageProvider
        let manager: SessionManager
    }

    private func makeSUT(loaderHonors: Bool = false, providerHonors: Bool = false) async -> SUT {
        let loader = GatedLinkPreviewLoader()
        loader.gate.honorsCancellation = loaderHonors
        let provider = GatedProductImageProvider()
        provider.gate.honorsCancellation = providerHonors
        let service = LinkPreviewService(repository: loader, provider: provider)
        let manager = SessionManager(initialClearables: [])
        await manager.register(service)
        return SUT(service: service, loader: loader, provider: provider, manager: manager)
    }

    private func start(_ service: LinkPreviewService) -> Task<String?, Never> {
        Task { @MainActor in await service.imageUrl(for: Self.page) }
    }

    // MARK: Repository cancellation

    @Test("a CancellationError from the repository is nil and the provider is never called")
    func repositoryCancellation() async {
        let sut = await makeSUT()
        sut.loader.enqueueFailure(CancellationError())
        sut.provider.enqueue(Self.deviceImage)

        let result = await sut.service.imageUrl(for: Self.page)

        #expect(result == nil)
        #expect(sut.provider.callCount == 0)
    }

    @Test("a CancellationError thrown by a held repository call is nil and the provider is never called")
    func heldRepositoryCancellation() async {
        let sut = await makeSUT()
        sut.loader.enqueueFailure(CancellationError(), held: true)
        sut.provider.enqueue(Self.deviceImage)
        let task = start(sut.service)
        await sut.loader.gate.nextHeldCall()

        sut.loader.gate.releaseAll()

        #expect(await task.value == nil)
        #expect(sut.provider.callCount == 0)
    }

    // MARK: Caller cancelled during the API step

    @Test("caller cancelled during the API step: provider never called, even when the API answers nil late",
          arguments: [false, true])
    func callerCancelledDuringApi(honors: Bool) async {
        let sut = await makeSUT(loaderHonors: honors)
        sut.loader.enqueue(nil, held: true)
        sut.provider.enqueue(Self.deviceImage)
        let task = start(sut.service)
        await sut.loader.gate.nextHeldCall()

        task.cancel()
        sut.loader.gate.releaseAll()
        let result = await task.value

        #expect(result == nil)
        #expect(sut.provider.callCount == 0)
    }

    @Test("caller cancelled during the API step: a late non-cancellation error does not start the provider",
          arguments: [false, true])
    func callerCancelledThenApiError(honors: Bool) async {
        let sut = await makeSUT(loaderHonors: honors)
        sut.loader.enqueueFailure(URLError(.timedOut), held: true)
        sut.provider.enqueue(Self.deviceImage)
        let task = start(sut.service)
        await sut.loader.gate.nextHeldCall()

        task.cancel()
        sut.loader.gate.releaseAll()

        #expect(await task.value == nil)
        #expect(sut.provider.callCount == 0)
    }

    // MARK: Session end during the API step

    @Test("session end during the API step: nil and the provider is never called", arguments: [false, true])
    func sessionEndDuringApi(honors: Bool) async {
        let sut = await makeSUT(loaderHonors: honors)
        sut.loader.enqueue(nil, held: true)
        sut.provider.enqueue(Self.deviceImage)
        let task = start(sut.service)
        await sut.loader.gate.nextHeldCall()
        let before = sut.service.sessionGeneration

        await sut.manager.teardown(reason: .userLogout)
        sut.loader.gate.releaseAll()
        let result = await task.value

        #expect(result == nil)
        #expect(sut.provider.callCount == 0)
        #expect(sut.service.sessionGeneration == before + 1)
    }

    @Test("session end during the API step with a late error: provider never called", arguments: [false, true])
    func sessionEndDuringApiError(honors: Bool) async {
        let sut = await makeSUT(loaderHonors: honors)
        sut.loader.enqueueFailure(URLError(.timedOut), held: true)
        sut.provider.enqueue(Self.deviceImage)
        let task = start(sut.service)
        await sut.loader.gate.nextHeldCall()

        try? await sut.service.clearForSession()
        sut.loader.gate.releaseAll()

        #expect(await task.value == nil)
        #expect(sut.provider.callCount == 0)
    }

    // MARK: Caller cancelled during the provider step

    @Test("caller cancelled during the provider step: the provider observes cancellation, result nil")
    func callerCancelledDuringProvider() async {
        let sut = await makeSUT(providerHonors: true)
        sut.loader.enqueue(nil)
        sut.provider.enqueue(Self.deviceImage, held: true)
        let task = start(sut.service)
        await sut.provider.gate.nextHeldCall()
        let before = sut.service.sessionGeneration

        task.cancel()
        // No release: the provider can only end because the service cancelled it.
        let result = await task.value

        #expect(result == nil)
        #expect(sut.provider.cancelledCallCount == 1)
        #expect(sut.service.sessionGeneration == before, "caller cancellation is not a session end")
    }

    @Test("caller cancelled during the provider step: a late value is dropped by a provider that ignores cancellation")
    func callerCancelledLateProviderValue() async {
        let sut = await makeSUT(providerHonors: false)
        sut.loader.enqueue(nil)
        sut.provider.enqueue(Self.deviceImage, held: true)
        let task = start(sut.service)
        await sut.provider.gate.nextHeldCall()

        task.cancel()
        sut.provider.gate.releaseAll()

        #expect(await task.value == nil)
    }

    @Test("a provider that throws CancellationError gives nil")
    func providerThrowsCancellation() async {
        let sut = await makeSUT()
        sut.loader.enqueue(nil)
        sut.provider.enqueueFailure(CancellationError())

        #expect(await sut.service.imageUrl(for: Self.page) == nil)
        #expect(sut.provider.callCount == 1)
    }

    // MARK: Session end during the provider step

    @Test("clearForSession cancels the in-flight provider call: it ends without any release, result nil")
    func sessionEndCancelsProvider() async throws {
        let sut = await makeSUT(providerHonors: true)
        sut.loader.enqueue(nil)
        sut.provider.enqueue(Self.deviceImage, held: true)
        let task = start(sut.service)
        await sut.provider.gate.nextHeldCall()

        try await sut.service.clearForSession()
        let result = await task.value

        #expect(result == nil)
        #expect(sut.provider.cancelledCallCount == 1)
    }

    @Test("session end during the provider step: a late value is dropped and nothing else changes",
          arguments: [false, true])
    func sessionEndDropsLateProviderValue(honors: Bool) async {
        let sut = await makeSUT(providerHonors: honors)
        sut.loader.enqueue(nil)
        sut.provider.enqueue(Self.deviceImage, held: true)
        let task = start(sut.service)
        await sut.provider.gate.nextHeldCall()
        let before = sut.service.sessionGeneration

        await sut.manager.teardown(reason: .userLogout)
        sut.provider.gate.releaseAll()
        let result = await task.value

        #expect(result == nil, "a stale provider value must not be returned")
        #expect(sut.service.sessionGeneration == before + 1)
    }

    @Test("teardown for every reason during the provider step drops the call",
          arguments: [TeardownReason.userLogout, .sessionExpired, .forcedUpdate, .lockFallback])
    func everyReasonDuringProvider(reason: TeardownReason) async {
        let sut = await makeSUT()
        sut.loader.enqueue(nil)
        sut.provider.enqueue(Self.deviceImage, held: true)
        let task = start(sut.service)
        await sut.provider.gate.nextHeldCall()

        await sut.manager.teardown(reason: reason)
        sut.provider.gate.releaseAll()

        #expect(await task.value == nil)
    }

    // MARK: Recovery

    @Test("a call after a session end works normally, API step and provider step")
    func callAfterSessionEnd() async {
        let sut = await makeSUT(providerHonors: true)
        sut.loader.enqueue(nil)
        sut.provider.enqueue(Self.deviceImage, held: true)
        let first = start(sut.service)
        await sut.provider.gate.nextHeldCall()
        await sut.manager.teardown(reason: .userLogout)
        sut.provider.gate.releaseAll()
        _ = await first.value
        sut.loader.enqueue(nil)
        sut.provider.enqueue("https://images.example.test/second.jpg")

        #expect(await sut.service.imageUrl(for: Self.page) == "https://images.example.test/second.jpg")
    }

    @Test("a cancelled call does not break the next call")
    func nextCallAfterCancellation() async {
        let sut = await makeSUT(providerHonors: true)
        sut.loader.enqueue(nil)
        sut.provider.enqueue(Self.deviceImage, held: true)
        let task = start(sut.service)
        await sut.provider.gate.nextHeldCall()
        task.cancel()
        _ = await task.value
        sut.loader.enqueue(nil)
        sut.provider.enqueue("https://images.example.test/next.jpg")

        #expect(await sut.service.imageUrl(for: Self.page) == "https://images.example.test/next.jpg")
    }
}
