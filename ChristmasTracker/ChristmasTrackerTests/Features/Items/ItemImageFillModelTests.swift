//
//  ItemImageFillModelTests.swift
//  ChristmasTrackerTests
//
//  IMG1-P3: the model that owns the lookup task. A real LinkPreviewService over the gated loader
//  (or the mock repository) feeds it; `apply` records what the form would receive.
//
//  Determinism: held calls use the gate handshake; "nothing applied" is proven by waiting for the
//  model to leave the looking state (observation, no sleeps) or, after cancel(), by a sentinel
//  lookup whose own apply is awaited. No polling.
//
//  Covers ItemImageFillModel.
//

import Testing
import Foundation
import Observation
@testable import ChristmasTracker

@Suite("Item image fill model Tests", .timeLimit(.minutes(1)))
@MainActor
struct ItemImageFillModelTests {

    private static let page = "https://shop.example.test/p/1"
    private static let otherPage = "https://shop.example.test/p/2"
    private static let image = "https://images.example.test/a.jpg"
    private static let otherImage = "https://images.example.test/b.jpg"

    /// What the form shows and receives. `current` reads the live field values.
    @MainActor
    private final class FormProbe {
        var url = ItemImageFillModelTests.page
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

        /// The next applied value not yet claimed (suspends until one arrives).
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

    private func makeSUT(mode: ItemFormMode = .add, honorsCancellation: Bool = false) -> SUT {
        let loader = GatedLinkPreviewLoader()
        loader.gate.honorsCancellation = honorsCancellation
        return SUT(model: ItemImageFillModel(mode: mode), service: LinkPreviewService(repository: loader),
                   loader: loader, probe: FormProbe())
    }

    private func start(_ sut: SUT, url: String = page) {
        let probe = sut.probe
        sut.model.urlEditingFinished(
            url: url, imageUrl: probe.imageUrl, service: sut.service,
            current: { (url: probe.url, imageUrl: probe.imageUrl) },
            apply: { probe.record($0) }
        )
    }

    /// Suspends until the model is no longer looking (observation-based, no polling).
    private func untilIdle(_ model: ItemImageFillModel) async {
        while model.isLooking {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                withObservationTracking {
                    _ = model.isLooking
                } onChange: {
                    continuation.resume()
                }
            }
        }
    }

    // MARK: - Success

    @Test("A successful lookup applies the image exactly once and ends in the fetched state")
    func fillAppliedOnce() async {
        let sut = makeSUT()
        sut.loader.enqueue(Self.image)

        start(sut)
        let first = await sut.probe.nextApplied()
        await untilIdle(sut.model)

        #expect(first == Self.image)
        #expect(sut.probe.applied == [Self.image])
        #expect(sut.model.state.source == .fetched)
        #expect(sut.loader.calls == [Self.page])
    }

    @Test("The mock repository fills a known host")
    func mockRepositoryFills() async {
        let model = ItemImageFillModel(mode: .add)
        let service = LinkPreviewService(repository: MockLinkPreviewRepository())
        let probe = FormProbe()
        probe.url = "https://\(MockLinkPreviewRepository.knownHost)/p/1"

        model.urlEditingFinished(
            url: probe.url, imageUrl: "", service: service,
            current: { (url: probe.url, imageUrl: probe.imageUrl) },
            apply: { probe.record($0) }
        )

        #expect(await probe.nextApplied() == MockLinkPreviewRepository.fixedImageUrl)
    }

    @Test("isLooking is true while the call is held and false after it finishes")
    func isLookingWhileHeld() async {
        let sut = makeSUT()
        sut.loader.enqueue(Self.image, held: true)

        start(sut)
        await sut.loader.gate.nextHeldCall()
        #expect(sut.model.isLooking)
        #expect(sut.model.state.isLooking)

        sut.loader.gate.releaseAll()
        #expect(await sut.probe.nextApplied() == Self.image)
        #expect(!sut.model.isLooking)
    }

    @Test("The model passes the current field values, not the ones at start, to the state")
    func usesCurrentValues() async {
        let sut = makeSUT()
        sut.loader.enqueue(Self.image, held: true)

        start(sut)
        await sut.loader.gate.nextHeldCall()
        sut.probe.url = Self.otherPage   // the user edited the url while the call ran
        sut.loader.gate.releaseAll()
        await untilIdle(sut.model)

        #expect(sut.probe.applied.isEmpty)
    }

    @Test("An image typed while the call ran is not overwritten")
    func typedMeanwhileNotOverwritten() async {
        let sut = makeSUT()
        sut.loader.enqueue(Self.image, held: true)

        start(sut)
        await sut.loader.gate.nextHeldCall()
        sut.probe.imageUrl = "https://images.example.test/mine.jpg"
        sut.model.imageTextChanged(to: sut.probe.imageUrl)
        sut.loader.gate.releaseAll()
        await untilIdle(sut.model)

        #expect(sut.probe.applied.isEmpty)
    }

    // MARK: - Nothing to apply

    @Test("A nil result applies nothing and clears isLooking")
    func nilResult() async {
        let sut = makeSUT()
        sut.loader.enqueue(nil, held: true)

        start(sut)
        await sut.loader.gate.nextHeldCall()
        #expect(sut.model.isLooking)
        sut.loader.gate.releaseAll()
        await untilIdle(sut.model)

        #expect(sut.probe.applied.isEmpty)
        #expect(!sut.model.isLooking)
    }

    @Test("An invalid url starts nothing")
    func invalidUrlStartsNothing() {
        let sut = makeSUT()

        start(sut, url: "ftp://shop.example.test/p")

        #expect(!sut.model.isLooking)
        #expect(sut.loader.callCount == 0)
    }

    // MARK: - Supersede, cancel, session end

    @Test("A new accepted lookup cancels the old task: the first result is never applied", arguments: [false, true])
    func newCallCancelsOld(honorsCancellation: Bool) async {
        let sut = makeSUT(honorsCancellation: honorsCancellation)
        sut.loader.enqueue(Self.image, held: true)
        sut.loader.enqueue(Self.otherImage)

        start(sut, url: Self.page)
        await sut.loader.gate.nextHeldCall()
        sut.probe.url = Self.otherPage
        start(sut, url: Self.otherPage)
        #expect(await sut.probe.nextApplied() == Self.otherImage)

        sut.loader.gate.releaseAll()
        // Sentinel: a third lookup whose apply is awaited orders everything before it.
        sut.loader.enqueue("https://images.example.test/sentinel.jpg")
        sut.probe.url = "https://shop.example.test/p/3"
        sut.probe.imageUrl = ""
        sut.model.imageTextChanged(to: "")
        start(sut, url: sut.probe.url)
        _ = await sut.probe.nextApplied()

        #expect(sut.probe.applied == [Self.otherImage, "https://images.example.test/sentinel.jpg"])
        #expect(!sut.probe.applied.contains(Self.image))
    }

    @Test("cancel() applies nothing and clears isLooking at once", arguments: [false, true])
    func cancelAppliesNothing(honorsCancellation: Bool) async {
        let sut = makeSUT(honorsCancellation: honorsCancellation)
        sut.loader.enqueue(Self.image, held: true)

        start(sut)
        await sut.loader.gate.nextHeldCall()
        sut.model.cancel()
        #expect(!sut.model.isLooking)
        sut.loader.gate.releaseAll()

        // Sentinel: a later lookup whose apply is awaited orders everything before it.
        sut.loader.enqueue("https://images.example.test/sentinel.jpg")
        sut.probe.url = Self.otherPage
        start(sut, url: Self.otherPage)
        _ = await sut.probe.nextApplied()

        #expect(sut.probe.applied == ["https://images.example.test/sentinel.jpg"])
    }

    @Test("A session end during a call applies nothing and shows nothing", arguments: [false, true])
    func sessionEndAppliesNothing(honorsCancellation: Bool) async throws {
        let sut = makeSUT(honorsCancellation: honorsCancellation)
        sut.loader.enqueue(Self.image, held: true)

        start(sut)
        await sut.loader.gate.nextHeldCall()
        try await sut.service.clearForSession()
        sut.loader.gate.releaseAll()
        await untilIdle(sut.model)

        #expect(sut.probe.applied.isEmpty)
        #expect(!sut.model.isLooking)
    }

    @Test("Edit mode: an unchanged saved url starts nothing")
    func editSavedUrlStartsNothing() {
        let sut = makeSUT(mode: .edit(savedUrl: Self.page))

        start(sut)

        #expect(!sut.model.isLooking)
        #expect(sut.loader.callCount == 0)
    }
}
