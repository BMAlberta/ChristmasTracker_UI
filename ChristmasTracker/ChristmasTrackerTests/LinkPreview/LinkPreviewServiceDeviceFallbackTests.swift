//
//  LinkPreviewServiceDeviceFallbackTests.swift
//  ChristmasTrackerTests
//
//  IMG1-P4 (decisions 4 and 11): the order of the two steps in LinkPreviewService.imageUrl(for:).
//
//   - an invalid page URL calls neither the repository nor the provider;
//   - an accepted API value is returned and the provider is NOT called;
//   - API nil, an API value the filter rejects, and a non-cancellation API error each call the
//     provider exactly once with the same page URL;
//   - the provider's value goes through ProductImageURLNormalizer, then LinkPreviewImageFilter;
//   - nil from the provider is nil.
//
//  Determinism: scripted fakes, no sleeps, no network.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("LinkPreviewService device fallback", .timeLimit(.minutes(1)))
@MainActor
struct LinkPreviewServiceDeviceFallbackTests {

    private static let page = "https://shop.example.test/p/1"
    private static let apiImage = "https://images.example.test/api.jpg"
    private static let deviceImage = "https://images.example.test/device.jpg"

    private struct SUT {
        let service: LinkPreviewService
        let loader: GatedLinkPreviewLoader
        let provider: GatedProductImageProvider
    }

    private func makeSUT() -> SUT {
        let loader = GatedLinkPreviewLoader()
        let provider = GatedProductImageProvider()
        let service = LinkPreviewService(repository: loader, provider: provider)
        return SUT(service: service, loader: loader, provider: provider)
    }

    // MARK: Input

    @Test("an invalid page URL calls neither step", arguments: [
        "",
        "ftp://shop.example.test/p",
        "https://user:pw@shop.example.test/p",
        "https://shop.example.test/a b",
        "https://shop.example.test/" + String(repeating: "a", count: 2100)
    ])
    func invalidInput(url: String) async {
        let sut = makeSUT()
        sut.loader.enqueue(Self.apiImage)
        sut.provider.enqueue(Self.deviceImage)

        let result = await sut.service.imageUrl(for: url)

        #expect(result == nil)
        #expect(sut.loader.callCount == 0)
        #expect(sut.provider.callCount == 0)
    }

    // MARK: API value wins

    @Test("an accepted API value is returned and the provider is not called")
    func apiValueSkipsProvider() async {
        let sut = makeSUT()
        sut.loader.enqueue(Self.apiImage)
        sut.provider.enqueue(Self.deviceImage)

        let result = await sut.service.imageUrl(for: Self.page)

        #expect(result == Self.apiImage)
        #expect(sut.loader.calls == [Self.page])
        #expect(sut.provider.callCount == 0)
    }

    // MARK: Provider runs

    @Test("API nil calls the provider once with the same page URL")
    func apiNil() async {
        let sut = makeSUT()
        sut.loader.enqueue(nil)
        sut.provider.enqueue(Self.deviceImage)

        let result = await sut.service.imageUrl(for: Self.page)

        #expect(result == Self.deviceImage)
        #expect(sut.loader.callCount == 1)
        #expect(sut.provider.calls == [Self.page])
    }

    @Test("a non-cancellation API error calls the provider once")
    func apiError() async {
        let sut = makeSUT()
        sut.loader.enqueueFailure(URLError(.timedOut))
        sut.provider.enqueue(Self.deviceImage)

        let result = await sut.service.imageUrl(for: Self.page)

        #expect(result == Self.deviceImage)
        #expect(sut.provider.calls == [Self.page])
    }

    @Test("an API value the filter rejects calls the provider once", arguments: [
        "http://images.example.test/a.jpg",
        "https://user:pw@images.example.test/a.jpg",
        "https://images.example.test/a b.jpg",
        "ftp://images.example.test/a.jpg",
        "https://images.example.test/" + String(repeating: "a", count: 2100)
    ])
    func apiValueFilteredOut(value: String) async {
        let sut = makeSUT()
        sut.loader.enqueue(value)
        sut.provider.enqueue(Self.deviceImage)

        let result = await sut.service.imageUrl(for: Self.page)

        #expect(result == Self.deviceImage)
        #expect(sut.provider.calls == [Self.page])
    }

    @Test("a provider nil gives nil")
    func providerNil() async {
        let sut = makeSUT()
        sut.loader.enqueue(nil)
        sut.provider.enqueue(nil)

        #expect(await sut.service.imageUrl(for: Self.page) == nil)
        #expect(sut.provider.callCount == 1)
    }

    @Test("an API nil with an empty provider script is nil")
    func providerDefaultsToNil() async {
        let sut = makeSUT()
        sut.loader.enqueue(nil)

        #expect(await sut.service.imageUrl(for: Self.page) == nil)
    }

    // MARK: Provider value normalization, through the service

    @Test("the provider value is normalized for every accepted case",
          arguments: ProductImageURLNormalizerTests.accepted)
    func providerAccepted(raw: String, expected: String) async {
        let sut = makeSUT()
        sut.loader.enqueue(nil)
        sut.provider.enqueue(raw)

        #expect(await sut.service.imageUrl(for: Self.page) == expected)
    }

    @Test("the provider value is dropped for every rejected case",
          arguments: ProductImageURLNormalizerTests.rejected)
    func providerRejected(raw: String) async {
        let sut = makeSUT()
        sut.loader.enqueue(nil)
        sut.provider.enqueue(raw)

        #expect(await sut.service.imageUrl(for: Self.page) == nil)
    }

    @Test("the provider's http value is upgraded to https")
    func providerHttpUpgraded() async {
        let sut = makeSUT()
        sut.loader.enqueue(nil)
        sut.provider.enqueue("http://images.example.test/d.jpg?w=2")

        #expect(await sut.service.imageUrl(for: Self.page) == "https://images.example.test/d.jpg?w=2")
    }

    // MARK: Default provider

    @Test("without a provider argument the service uses the inert provider: API nil is nil")
    func defaultProviderIsInert() async {
        let loader = GatedLinkPreviewLoader()
        loader.enqueue(nil)
        let service = LinkPreviewService(repository: loader)

        #expect(await service.imageUrl(for: Self.page) == nil)
    }
}
