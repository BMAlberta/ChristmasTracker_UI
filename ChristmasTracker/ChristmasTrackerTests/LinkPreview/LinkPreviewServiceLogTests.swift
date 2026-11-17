//
//  LinkPreviewServiceLogTests.swift
//  ChristmasTrackerTests
//
//  LG1-L3 batch C: the step lines LinkPreviewService writes through ServiceLog for its two calls (the API
//  lookup and the device fallback): started and processed on success, exactly one error on a failure,
//  cancelled (never an error) when the caller is cancelled or the session ends, nothing for an invalid page
//  URL (no call is made), only the failure line in a Release-style run, and never a page URL, host or image
//  value in any line.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("LinkPreviewService log Tests", .timeLimit(.minutes(1)))
@MainActor
struct LinkPreviewServiceLogTests {

    private static let page = "https://zz-secret.example/item"
    private static let image = "https://images.zz-secret.example/pic.jpg"

    private struct Rig {
        let service: LinkPreviewService
        let loader: GatedLinkPreviewLoader
        let provider: GatedProductImageProvider
        let sink: CapturingOperationLog
    }

    private func makeRig(verbose: Bool = true, honorsCancellation: Bool = false) -> Rig {
        let loader = GatedLinkPreviewLoader()
        loader.gate.honorsCancellation = honorsCancellation
        let provider = GatedProductImageProvider()
        provider.gate.honorsCancellation = honorsCancellation
        let sink = CapturingOperationLog()
        let log = ServiceLog(sink: sink, verbosity: LogVerbosity(isVerbose: verbose))
        let service = LinkPreviewService(repository: loader, provider: provider, log: log)
        return Rig(service: service, loader: loader, provider: provider, sink: sink)
    }

    private func messages(_ rig: Rig) -> [String] { rig.sink.lines.map(\.message) }

    private func errors(_ rig: Rig) -> [String] {
        rig.sink.lines.filter { $0.level == .error }.map(\.message)
    }

    @Test("an API answer logs started then processed and no device step")
    func apiSuccess() async {
        let rig = makeRig()
        rig.loader.enqueue(Self.image)

        let result = await rig.service.imageUrl(for: Self.page)

        #expect(result == Self.image)
        #expect(messages(rig) == ["link preview lookup started", "link preview lookup processed"])
    }

    @Test("an API answer of nothing falls back to the device and logs both steps")
    func deviceFallback() async {
        let rig = makeRig()
        rig.loader.enqueue(nil)
        rig.provider.enqueue(Self.image)

        let result = await rig.service.imageUrl(for: Self.page)

        #expect(result == Self.image)
        #expect(messages(rig) == [
            "link preview lookup started", "link preview lookup processed",
            "device link preview started", "device link preview processed"
        ])
    }

    @Test("a failed API call logs exactly one error and the device fallback still runs")
    func apiFailure() async {
        let rig = makeRig()
        rig.loader.enqueueFailure(URLError(.timedOut))
        rig.provider.enqueue(nil)

        let result = await rig.service.imageUrl(for: Self.page)

        #expect(result == nil)
        #expect(errors(rig) == ["link preview lookup failed"])
        #expect(rig.provider.callCount == 1)
    }

    @Test("a failed device call logs exactly one error")
    func deviceFailure() async {
        let rig = makeRig()
        rig.loader.enqueue(nil)
        rig.provider.enqueueFailure(URLError(.badServerResponse))

        let result = await rig.service.imageUrl(for: Self.page)

        #expect(result == nil)
        #expect(errors(rig) == ["device link preview failed"])
    }

    @Test("a caller cancelled during the API call logs cancelled and no error")
    func apiCancellation() async {
        let rig = makeRig(honorsCancellation: true)
        rig.loader.enqueue(nil, held: true)
        let task = Task { @MainActor in await rig.service.imageUrl(for: Self.page) }
        await rig.loader.gate.nextHeldCall()

        task.cancel()
        let result = await task.value

        #expect(result == nil)
        #expect(messages(rig) == ["link preview lookup started", "link preview lookup cancelled"])
        #expect(errors(rig).isEmpty)
    }

    @Test("a session that ends during the API call with a late error logs cancelled and no error")
    func sessionEndLateError() async throws {
        let rig = makeRig()
        rig.loader.enqueueFailure(URLError(.timedOut), held: true)
        let task = Task { @MainActor in await rig.service.imageUrl(for: Self.page) }
        await rig.loader.gate.nextHeldCall()

        try await rig.service.clearForSession()
        rig.loader.gate.releaseAll()
        let result = await task.value

        #expect(result == nil)
        #expect(messages(rig) == ["link preview lookup started", "link preview lookup cancelled"])
        #expect(errors(rig).isEmpty)
    }

    @Test("a caller cancelled during the device call logs cancelled and no error")
    func deviceCancellation() async {
        let rig = makeRig(honorsCancellation: true)
        rig.loader.enqueue(nil)
        rig.provider.enqueue(Self.image, held: true)
        let task = Task { @MainActor in await rig.service.imageUrl(for: Self.page) }
        await rig.provider.gate.nextHeldCall()

        task.cancel()
        let result = await task.value

        #expect(result == nil)
        #expect(messages(rig).suffix(2) == ["device link preview started", "device link preview cancelled"])
        #expect(errors(rig).isEmpty)
    }

    @Test("an invalid page URL makes no call and logs nothing")
    func invalidUrl() async {
        let rig = makeRig()

        let result = await rig.service.imageUrl(for: "not a url")

        #expect(result == nil)
        #expect(rig.loader.callCount == 0)
        #expect(rig.sink.lines.isEmpty)
    }

    @Test("a Release-style run logs only the failure line")
    func nonVerbose() async {
        let rig = makeRig(verbose: false)
        rig.loader.enqueue(Self.image)
        rig.loader.enqueueFailure(URLError(.timedOut))
        rig.provider.enqueue(nil)

        _ = await rig.service.imageUrl(for: Self.page)
        #expect(rig.sink.lines.isEmpty)

        _ = await rig.service.imageUrl(for: Self.page)
        #expect(messages(rig) == ["link preview lookup failed"])
        #expect(rig.sink.lines.map(\.level) == [.error])
    }

    @Test("the page URL, its host and the image value never appear in any line")
    func noSecrets() async {
        let rig = makeRig()
        rig.loader.enqueueFailure(URLError(.timedOut))
        rig.provider.enqueueFailure(URLError(.badServerResponse))
        rig.loader.enqueue(Self.image)
        rig.loader.enqueue(nil)
        rig.provider.enqueue(Self.image)

        _ = await rig.service.imageUrl(for: Self.page)
        _ = await rig.service.imageUrl(for: Self.page)
        _ = await rig.service.imageUrl(for: Self.page)

        #expect(!rig.sink.lines.isEmpty)
        for line in rig.sink.lines {
            #expect(!line.message.contains("zz-secret"))
            #expect(!line.message.contains("http"))
            #expect(!line.message.contains("example"))
        }
    }
}
