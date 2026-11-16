//
//  LinkPreviewServiceTests.swift
//  ChristmasTrackerTests
//
//  IMG1-P1: LinkPreviewService behavior without session events.
//
//  Rules under test:
//   - an invalid page URL makes NO repository call and returns nil;
//   - a valid http or https page URL reaches the repository unchanged;
//   - the repository value passes through LinkPreviewImageFilter (http, userinfo, over-long and
//     whitespace values become nil; a good https value is returned);
//   - nil from the repository is nil; any thrown error (CancellationError included) is nil.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("LinkPreviewService", .timeLimit(.minutes(1)))
@MainActor
struct LinkPreviewServiceTests {

    private static let page = "https://shop.example.test/p/1"
    private static let goodImage = "https://images.example.test/a.jpg"

    private struct SUT {
        let service: LinkPreviewService
        let loader: GatedLinkPreviewLoader
    }

    private func makeSUT() -> SUT {
        let loader = GatedLinkPreviewLoader()
        return SUT(service: LinkPreviewService(repository: loader), loader: loader)
    }

    // MARK: Input validation

    @Test("an invalid page URL makes no repository call and returns nil", arguments: [
        "",
        "ftp://shop.example.test/p",
        "javascript:alert(1)",
        "https://",
        "https:///path",
        "https://user:pw@shop.example.test/p",
        "https://shop.example.test/a b",
        "https://shop.example.test/" + String(repeating: "a", count: 2100)
    ])
    func invalidInput(url: String) async {
        let sut = makeSUT()
        sut.loader.enqueue(Self.goodImage)

        let result = await sut.service.imageUrl(for: url)

        #expect(result == nil)
        #expect(sut.loader.callCount == 0, "an invalid URL must never be sent")
    }

    @Test("a valid page URL is sent to the repository unchanged", arguments: [
        "https://shop.example.test/p/1",
        "http://shop.example.test/p/1"
    ])
    func validInput(url: String) async {
        let sut = makeSUT()
        sut.loader.enqueue(Self.goodImage)

        let result = await sut.service.imageUrl(for: url)

        #expect(result == Self.goodImage)
        #expect(sut.loader.calls == [url])
    }

    // MARK: Result filter

    @Test("a good https value is returned")
    func goodValue() async {
        let sut = makeSUT()
        sut.loader.enqueue(Self.goodImage)

        #expect(await sut.service.imageUrl(for: Self.page) == Self.goodImage)
    }

    @Test("a value the filter rejects becomes nil", arguments: [
        "http://images.example.test/a.jpg",
        "https://user:pw@images.example.test/a.jpg",
        "https://user@images.example.test/a.jpg",
        "https://images.example.test/a b.jpg",
        "https://images.example.test/" + String(repeating: "a", count: 2100),
        "",
        "ftp://images.example.test/a.jpg"
    ])
    func rejectedValue(value: String) async {
        let sut = makeSUT()
        sut.loader.enqueue(value)

        let result = await sut.service.imageUrl(for: Self.page)

        #expect(result == nil)
        #expect(sut.loader.callCount == 1)
    }

    @Test("a nil repository result is nil")
    func nilValue() async {
        let sut = makeSUT()
        sut.loader.enqueue(nil)

        #expect(await sut.service.imageUrl(for: Self.page) == nil)
    }

    // MARK: Errors

    @Test("any thrown error returns nil and does not escape", arguments: [
        URLError(.notConnectedToInternet) as any Error,
        CancellationError() as any Error,
        URLError(.cancelled) as any Error,
        BudgetError.server as any Error
    ])
    func thrownErrorIsNil(error: any Error) async {
        let sut = makeSUT()
        sut.loader.enqueueFailure(error)

        let result = await sut.service.imageUrl(for: Self.page)

        #expect(result == nil)
        #expect(sut.loader.callCount == 1)
    }

    @Test("a failure does not break the next call")
    func nextCallAfterFailure() async {
        let sut = makeSUT()
        sut.loader.enqueueFailure(URLError(.timedOut))
        sut.loader.enqueue(Self.goodImage)

        _ = await sut.service.imageUrl(for: Self.page)
        let second = await sut.service.imageUrl(for: Self.page)

        #expect(second == Self.goodImage)
    }

    @Test("normal calls do not change the session generation")
    func generationUnchangedByCalls() async {
        let sut = makeSUT()
        let before = sut.service.sessionGeneration
        sut.loader.enqueue(Self.goodImage)
        sut.loader.enqueueFailure(URLError(.timedOut))

        _ = await sut.service.imageUrl(for: Self.page)
        _ = await sut.service.imageUrl(for: Self.page)

        #expect(sut.service.sessionGeneration == before)
    }
}
