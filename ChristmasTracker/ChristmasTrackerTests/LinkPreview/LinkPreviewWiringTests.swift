//
//  LinkPreviewWiringTests.swift
//  ChristmasTrackerTests
//
//  IMG1-P1: makeLinkPreviewService(mode:state:client:) picks the right repository, observed only
//  through the service's behavior:
//   - bootstrap .failed is inert (nil even for the mock's known host, in either mode);
//   - mock mode + .ready answers from the mock repository;
//   - real mode + .ready calls the supplied client;
//   - real mode with no client is inert.
//

import Foundation
import Testing
import TrackerAPI
@testable import ChristmasTracker

@Suite("Link preview wiring", .timeLimit(.minutes(1)))
@MainActor
struct LinkPreviewWiringTests {

    private static let knownURL = "https://\(MockLinkPreviewRepository.knownHost)/p/1"
    private static let otherURL = "https://other.example.test/p/1"

    private func makeFakeClient() throws -> (client: any APIProtocol, transport: ListFakeTransport) {
        let transport = ListFakeTransport()
        let client = try TrackerClientFactory.make(
            serverURL: try #require(URL(string: "https://api.example.com")),
            info: AppClientInfo(platform: "ios", clientPlatform: "ios", build: "1", version: "1.0.0"),
            tokenProvider: ListFakeTokenProvider(token: "tok-access-FAKE"),
            sessionRefresher: ListFakeRefresher(),
            versionOutdatedHandler: ListFakeVersionHandler(),
            transport: transport
        )
        return (client, transport)
    }

    @Test("a failed bootstrap is inert in every mode, with or without a client", arguments: [APIMode.mock, APIMode.real])
    func failedIsInert(mode: APIMode) async throws {
        let fake = try makeFakeClient()
        await fake.transport.enqueue(status: 200, json: ListWire.success(data: "{ \"imageUrl\": \"https://images.example.test/a.jpg\" }"))

        let withClient = makeLinkPreviewService(mode: mode, state: .failed, client: fake.client)
        let withoutClient = makeLinkPreviewService(mode: mode, state: .failed, client: nil)

        #expect(await withClient.imageUrl(for: Self.knownURL) == nil)
        #expect(await withoutClient.imageUrl(for: Self.knownURL) == nil)
        #expect(await fake.transport.requestCount == 0, "an inert service never reaches the client")
    }

    @Test("mock mode with a ready bootstrap answers from the mock repository")
    func mockMode() async {
        let service = makeLinkPreviewService(mode: .mock, state: .ready, client: nil)

        #expect(await service.imageUrl(for: Self.knownURL) == MockLinkPreviewRepository.fixedImageUrl)
        #expect(await service.imageUrl(for: Self.otherURL) == nil)
    }

    @Test("real mode with a ready bootstrap and a client calls that client")
    func realModeUsesClient() async throws {
        let fake = try makeFakeClient()
        let image = "https://images.example.test/real.jpg"
        await fake.transport.enqueue(status: 200, json: ListWire.success(data: "{ \"imageUrl\": \"\(image)\" }"))
        let service = makeLinkPreviewService(mode: .real, state: .ready, client: fake.client)

        let result = await service.imageUrl(for: Self.otherURL)

        #expect(result == image)
        #expect(await fake.transport.requestCount == 1)
    }

    @Test("real mode does not answer from the mock repository")
    func realModeIsNotMock() async throws {
        let fake = try makeFakeClient()
        await fake.transport.enqueue(status: 200, json: ListWire.success(data: "{ \"imageUrl\": null }"))
        let service = makeLinkPreviewService(mode: .real, state: .ready, client: fake.client)

        #expect(await service.imageUrl(for: Self.knownURL) == nil)
    }

    @Test("real mode with no client is inert")
    func realModeWithoutClient() async {
        let service = makeLinkPreviewService(mode: .real, state: .ready, client: nil)

        #expect(await service.imageUrl(for: Self.knownURL) == nil)
    }
}
