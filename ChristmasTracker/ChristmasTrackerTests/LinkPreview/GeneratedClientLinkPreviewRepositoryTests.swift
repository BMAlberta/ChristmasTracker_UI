//
//  GeneratedClientLinkPreviewRepositoryTests.swift
//  ChristmasTrackerTests
//
//  IMG1-P1: getLinkPreview through the REAL factory-built client with a fake transport.
//
//  Rules under test:
//   - 200 with a string imageUrl returns it unchanged; 200 with null (or no key) returns nil;
//   - 400, 401, 403, 404, 429, 500, an undocumented status, a transport error and an undecodable
//     body all return nil WITHOUT throwing;
//   - CancellationError and URLError.cancelled propagate as CancellationError;
//   - the request is one POST /link-preview with the page URL in the JSON body.
//
//  These tests do not compile until the implementer adds LinkPreviewLoading and
//  GeneratedClientLinkPreviewRepository.
//

import Foundation
import HTTPTypes
import Testing
import TrackerAPI
@testable import ChristmasTracker

@Suite("GeneratedClientLinkPreviewRepository", .timeLimit(.minutes(1)))
struct GeneratedClientLinkPreviewRepositoryTests {

    private static let pageURL = "https://shop.example.test/product/1"

    private struct SUT {
        let repository: GeneratedClientLinkPreviewRepository
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
        return SUT(repository: GeneratedClientLinkPreviewRepository(client: client), transport: transport)
    }

    private func okBody(imageLiteral: String) -> String {
        ListWire.success(data: "{ \"imageUrl\": \(imageLiteral) }")
    }

    // MARK: 200

    @Test("200 with a string returns it unchanged")
    func okWithValue() async throws {
        let sut = try makeSUT()
        let value = "https://images.example.test/a.jpg?w=200&h=100"
        await sut.transport.enqueue(status: 200, json: okBody(imageLiteral: "\"\(value)\""))

        let result = try await sut.repository.imageUrl(for: Self.pageURL)

        #expect(result == value)
    }

    @Test("200 with null returns nil")
    func okWithNull() async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(status: 200, json: okBody(imageLiteral: "null"))

        let result = try await sut.repository.imageUrl(for: Self.pageURL)

        #expect(result == nil)
    }

    @Test("200 with the imageUrl key missing returns nil")
    func okWithMissingKey() async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(status: 200, json: ListWire.success(data: "{}"))

        let result = try await sut.repository.imageUrl(for: Self.pageURL)

        #expect(result == nil)
    }

    // MARK: Failures that are values

    @Test("these statuses return nil and do not throw", arguments: [400, 403, 404, 429, 500, 502, 418])
    func statusReturnsNil(status: Int) async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(status: status, json: ListWire.internalError, times: 2)

        let result = try await sut.repository.imageUrl(for: Self.pageURL)

        #expect(result == nil)
    }

    @Test("401 returns nil and does not throw")
    func unauthorizedReturnsNil() async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(status: 401, json: ListWire.tokenExpired, times: 2)

        let result = try await sut.repository.imageUrl(for: Self.pageURL)

        #expect(result == nil)
    }

    @Test("a 429 with a Retry-After header returns nil and does not throw")
    func rateLimitedWithRetryAfter() async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(status: 429, json: ListWire.rateLimit, retryAfter: "30", times: 2)

        let result = try await sut.repository.imageUrl(for: Self.pageURL)

        #expect(result == nil)
    }

    @Test("a transport error returns nil and does not throw")
    func transportError() async throws {
        let sut = try makeSUT()
        await sut.transport.enqueueThrow(URLError(.notConnectedToInternet))

        let result = try await sut.repository.imageUrl(for: Self.pageURL)

        #expect(result == nil)
    }

    @Test("an undecodable 200 body returns nil and does not throw", arguments: [
        "{ this is not json",
        "{ \"success\": true }",
        "{ \"success\": true, \"data\": { \"imageUrl\": 42 }, \"meta\": \(ListWire.metaJSON) }",
        "[]"
    ])
    func undecodableBody(body: String) async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(status: 200, json: body)

        let result = try await sut.repository.imageUrl(for: Self.pageURL)

        #expect(result == nil)
    }

    @Test("a 200 with no body at all returns nil and does not throw")
    func emptyBody() async throws {
        let sut = try makeSUT()
        await sut.transport.enqueueEmpty(status: 200)

        let result = try await sut.repository.imageUrl(for: Self.pageURL)

        #expect(result == nil)
    }

    // MARK: Cancellation

    @Test("a CancellationError from the transport propagates as CancellationError")
    func cancellationPropagates() async throws {
        let sut = try makeSUT()
        await sut.transport.enqueueThrow(CancellationError())

        await #expect(throws: CancellationError.self) {
            _ = try await sut.repository.imageUrl(for: Self.pageURL)
        }
    }

    @Test("URLError.cancelled from the transport propagates as CancellationError")
    func urlCancelledPropagates() async throws {
        let sut = try makeSUT()
        await sut.transport.enqueueThrow(URLError(.cancelled))

        await #expect(throws: CancellationError.self) {
            _ = try await sut.repository.imageUrl(for: Self.pageURL)
        }
    }

    // MARK: Request

    @Test("the request is one POST /link-preview with the page URL in the JSON body")
    func requestShape() async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(status: 200, json: okBody(imageLiteral: "null"))

        _ = try await sut.repository.imageUrl(for: Self.pageURL)

        let recorded = await sut.transport.recorded
        #expect(recorded.count == 1)
        let request = try #require(recorded.first)
        #expect(request.request.method == .post)
        #expect(request.pathOnly.hasSuffix("/link-preview"))
        #expect(request.jsonObject?["url"] as? String == Self.pageURL)
    }
}
