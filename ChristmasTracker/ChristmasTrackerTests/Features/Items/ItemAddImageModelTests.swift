//
//  ItemAddImageModelTests.swift
//  ChristmasTrackerTests
//
//  IMG1-P5: the model side of "Add image". A real LinkPreviewService over the gated loader feeds it;
//  `apply` records what the form would receive. Same task handling as the automatic lookup:
//  cancellable, silent on cancel and on session end, applies only a filtered value.
//
//  Determinism: held calls use the gate handshake; waiting uses observation (no sleeps, no polling).
//  "Nothing applied" after cancel() is proven by a sentinel request whose own apply is awaited.
//
//  Covers ItemImageFillModel.addImageRequested and addImageStatus.
//

import Testing
import Foundation
import Observation
@testable import ChristmasTracker

@Suite("Item add image model Tests", .timeLimit(.minutes(1)))
@MainActor
struct ItemAddImageModelTests {

    private static let page = "https://shop.example.test/p/1"
    private static let image = "https://images.example.test/a.jpg"
    private static let sentinel = "https://images.example.test/sentinel.jpg"

    @MainActor
    private final class FormProbe {
        var url = ItemAddImageModelTests.page
        var imageUrl = ""
        private(set) var applied: [String] = []
        private var unclaimed: [String] = []
        private var waiters: [CheckedContinuation<String, Never>] = []

        func record(_ value: String) {
            applied.append(value)
            if waiters.isEmpty {
                unclaimed.append(value)
            } else {
                waiters.removeFirst().resume(returning: value)
            }
        }

        func nextApplied() async -> String? {
            if !unclaimed.isEmpty { return unclaimed.removeFirst() }
            return await withCheckedContinuation { waiters.append($0) }
        }
    }

    private struct SUT {
        let model: ItemImageFillModel
        let service: LinkPreviewService
        let loader: GatedLinkPreviewLoader
        let probe: FormProbe
    }

    private func makeSUT(mode: ItemFormMode? = nil, honorsCancellation: Bool = false) -> SUT {
        let loader = GatedLinkPreviewLoader()
        loader.gate.honorsCancellation = honorsCancellation
        return SUT(model: ItemImageFillModel(mode: mode ?? .edit(savedUrl: Self.page)), service: LinkPreviewService(repository: loader),
                   loader: loader, probe: FormProbe())
    }

    private func tap(_ sut: SUT) {
        let probe = sut.probe
        sut.model.addImageRequested(
            url: probe.url, imageUrl: probe.imageUrl, service: sut.service,
            current: { (url: probe.url, imageUrl: probe.imageUrl) },
            apply: { probe.record($0) }
        )
    }

    /// Suspends until the add-image status is no longer running (observation-based).
    private func untilNotRunning(_ model: ItemImageFillModel) async {
        while model.addImageStatus == .running {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                withObservationTracking {
                    _ = model.addImageStatus
                } onChange: {
                    continuation.resume()
                }
            }
        }
    }

    // MARK: - Result

    @Test("A value is applied exactly once, ends idle and the url equals the saved one")
    func valueAppliedOnce() async {
        let sut = makeSUT()
        sut.loader.enqueue(Self.image)

        tap(sut)
        let first = await sut.probe.nextApplied()
        await untilNotRunning(sut.model)

        #expect(first == Self.image)
        #expect(sut.probe.applied == [Self.image])
        #expect(sut.model.addImageStatus == .idle)
        #expect(sut.model.state.source == .fetched)
        #expect(sut.loader.calls == [Self.page])
    }

    @Test("A nil result applies nothing and sets failed")
    func nilResultFails() async {
        let sut = makeSUT()
        sut.loader.enqueue(nil, held: true)

        tap(sut)
        await sut.loader.gate.nextHeldCall()
        sut.loader.gate.releaseAll()
        await untilNotRunning(sut.model)

        #expect(sut.probe.applied.isEmpty)
        #expect(sut.model.addImageStatus == .failed)
        #expect(!sut.model.isLooking)
    }

    @Test("After a failure a second tap runs again and can fill")
    func retryAfterFailure() async {
        let sut = makeSUT()
        sut.loader.enqueue(nil)
        sut.loader.enqueue(Self.image)

        tap(sut)
        await untilNotRunning(sut.model)
        #expect(sut.model.addImageStatus == .failed)

        tap(sut)
        #expect(await sut.probe.nextApplied() == Self.image)
        #expect(sut.model.addImageStatus == .idle)
        #expect(sut.loader.callCount == 2)
    }

    // MARK: - Status and one at a time

    @Test("The running status is observable while the call is held and ends when it finishes")
    func runningObservable() async {
        let sut = makeSUT()
        sut.loader.enqueue(Self.image, held: true)

        tap(sut)
        await sut.loader.gate.nextHeldCall()
        #expect(sut.model.addImageStatus == .running)
        #expect(sut.model.isLooking)

        sut.loader.gate.releaseAll()
        #expect(await sut.probe.nextApplied() == Self.image)
        #expect(sut.model.addImageStatus == .idle)
    }

    @Test("One lookup at a time: a second tap while running makes no second call")
    func oneAtATime() async {
        let sut = makeSUT()
        sut.loader.enqueue(Self.image, held: true)

        tap(sut)
        await sut.loader.gate.nextHeldCall()
        tap(sut)
        sut.loader.gate.releaseAll()
        #expect(await sut.probe.nextApplied() == Self.image)
        await untilNotRunning(sut.model)

        #expect(sut.loader.callCount == 1)
        #expect(sut.probe.applied == [Self.image])
    }

    @Test("Add mode: a tap starts nothing")
    func addModeStartsNothing() {
        let sut = makeSUT(mode: .add)

        tap(sut)

        #expect(sut.model.addImageStatus == .idle)
        #expect(!sut.model.isLooking)
        #expect(sut.loader.callCount == 0)
    }

    @Test("An invalid url starts nothing")
    func invalidUrlStartsNothing() {
        let sut = makeSUT()
        sut.probe.url = "ftp://shop.example.test/p"

        tap(sut)

        #expect(sut.model.addImageStatus == .idle)
        #expect(sut.loader.callCount == 0)
    }

    // MARK: - Cancel and session end

    @Test("cancel() applies nothing and sets idle at once", arguments: [false, true])
    func cancelAppliesNothing(honorsCancellation: Bool) async {
        let sut = makeSUT(honorsCancellation: honorsCancellation)
        sut.loader.enqueue(Self.image, held: true)

        tap(sut)
        await sut.loader.gate.nextHeldCall()
        sut.model.cancel()
        #expect(sut.model.addImageStatus == .idle)
        sut.loader.gate.releaseAll()

        // Sentinel: a later request whose apply is awaited orders everything before it.
        sut.loader.enqueue(Self.sentinel)
        tap(sut)
        _ = await sut.probe.nextApplied()

        #expect(sut.probe.applied == [Self.sentinel])
        #expect(sut.model.addImageStatus == .idle)
    }

    @Test("A session end during the call applies nothing and shows no failure", arguments: [false, true])
    func sessionEndAppliesNothing(honorsCancellation: Bool) async throws {
        let sut = makeSUT(honorsCancellation: honorsCancellation)
        sut.loader.enqueue(Self.image, held: true)

        tap(sut)
        await sut.loader.gate.nextHeldCall()
        try await sut.service.clearForSession()
        sut.loader.gate.releaseAll()
        await untilNotRunning(sut.model)

        #expect(sut.probe.applied.isEmpty)
        #expect(sut.model.addImageStatus == .idle)
    }

    @Test("A url changed while the call ran applies nothing and shows no failure")
    func urlChangedMeanwhile() async {
        let sut = makeSUT()
        sut.loader.enqueue(Self.image, held: true)

        tap(sut)
        await sut.loader.gate.nextHeldCall()
        sut.probe.url = "https://shop.example.test/p/2"
        sut.loader.gate.releaseAll()
        await untilNotRunning(sut.model)

        #expect(sut.probe.applied.isEmpty)
        #expect(sut.model.addImageStatus == .idle)
    }
}
