//
//  LinkPreviewServiceRateLimitFallbackTests.swift
//  ChristmasTrackerTests
//
//  IMG1-P4 (decision 4): a 429 from the REAL GeneratedClientLinkPreviewRepository, over the fake
//  transport, reaches the provider (the repository maps it to nil, the service then asks the device).
//

import Foundation
import Testing
import TrackerAPI
@testable import ChristmasTracker

@Suite("LinkPreviewService 429 fallback", .timeLimit(.minutes(1)))
@MainActor
struct LinkPreviewServiceRateLimitFallbackTests {

    private static let page = "https://shop.example.test/p/1"
    private static let deviceImage = "https://images.example.test/device.jpg"

    private struct SUT {
        let service: LinkPreviewService
        let provider: GatedProductImageProvider
        let transport: ListFakeTransport
    }

    private func makeSUT() throws -> SUT {
        let transport = ListFakeTransport()
        let client = try TrackerClientFactory.make(
            serverURL: try #require(URL(string: "https://api.example.com")),
            info: AppClientInfo(platform: "ios", clientPlatform: "ios", build: "1", version: "1.0.0"),
            tokenProvider: ListFakeTokenProvider(token: "tok-access-FAKE"),
            sessionRefresher: ListFakeRefresher(),
            versionOutdatedHandler: ListFakeVersionHandler(),
            transport: transport
        )
        let provider = GatedProductImageProvider()
        let service = LinkPreviewService(repository: GeneratedClientLinkPreviewRepository(client: client), provider: provider)
        return SUT(service: service, provider: provider, transport: transport)
    }

    @Test("429 calls the provider once and returns its image")
    func rateLimited() async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(status: 429, json: ListWire.rateLimit, retryAfter: "30", times: 2)
        sut.provider.enqueue(Self.deviceImage)

        let result = await sut.service.imageUrl(for: Self.page)

        #expect(result == Self.deviceImage)
        #expect(sut.provider.calls == [Self.page])
        #expect(await sut.transport.requestCount >= 1)
    }

    @Test("a 200 with an image does not call the provider")
    func okSkipsProvider() async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(
            status: 200,
            json: ListWire.success(data: "{ \"imageUrl\": \"https://images.example.test/api.jpg\" }")
        )
        sut.provider.enqueue(Self.deviceImage)

        let result = await sut.service.imageUrl(for: Self.page)

        #expect(result == "https://images.example.test/api.jpg")
        #expect(sut.provider.callCount == 0)
    }

    @Test("a 200 with null calls the provider once")
    func okNullCallsProvider() async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(status: 200, json: ListWire.success(data: "{ \"imageUrl\": null }"))
        sut.provider.enqueue(Self.deviceImage)

        #expect(await sut.service.imageUrl(for: Self.page) == Self.deviceImage)
        #expect(sut.provider.callCount == 1)
    }
}
