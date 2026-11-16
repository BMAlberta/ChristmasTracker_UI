//
//  LinkPreviewClientErrorWrappingTests.swift
//  ChristmasTrackerTests
//
//  IMG1-P1: the generated client wraps every transport failure in OpenAPIRuntime's ClientError
//  (underlyingError = the thrown error). Through the real factory-built client the repository must:
//   - turn a wrapped CancellationError or URLError(.cancelled) into CancellationError;
//   - return nil for a wrapped error of any other kind, without throwing.
//
//  The transport throws the bare cause and the client builds the ClientError, so no stub APIProtocol
//  is needed.
//

import Foundation
import Testing
import TrackerAPI
@testable import ChristmasTracker

@Suite("Link preview ClientError wrapping", .timeLimit(.minutes(1)))
struct LinkPreviewClientErrorWrappingTests {

    private struct OtherError: Error {}

    private func makeSUT() throws -> (repository: GeneratedClientLinkPreviewRepository, transport: ListFakeTransport) {
        let transport = ListFakeTransport()
        let client = try TrackerClientFactory.make(
            serverURL: try #require(URL(string: "https://api.example.com")),
            info: AppClientInfo(platform: "ios", clientPlatform: "ios", build: "1", version: "1.0.0"),
            tokenProvider: ListFakeTokenProvider(token: "tok-access-FAKE"),
            sessionRefresher: ListFakeRefresher(),
            versionOutdatedHandler: ListFakeVersionHandler(),
            transport: transport
        )
        return (GeneratedClientLinkPreviewRepository(client: client), transport)
    }

    @Test("a wrapped CancellationError or URLError.cancelled becomes CancellationError", arguments: [
        CancellationError() as any Error,
        URLError(.cancelled) as any Error
    ])
    func wrappedCancellation(cause: any Error) async throws {
        let sut = try makeSUT()
        await sut.transport.enqueueThrow(cause)

        await #expect(throws: CancellationError.self) {
            _ = try await sut.repository.imageUrl(for: "https://shop.example.test/p/1")
        }
    }

    @Test("a wrapped error of any other kind returns nil", arguments: [
        OtherError() as any Error,
        URLError(.timedOut) as any Error,
        URLError(.cannotFindHost) as any Error,
        CocoaError(.fileReadUnknown) as any Error
    ])
    func wrappedOther(cause: any Error) async throws {
        let sut = try makeSUT()
        await sut.transport.enqueueThrow(cause)

        let result = try await sut.repository.imageUrl(for: "https://shop.example.test/p/1")

        #expect(result == nil)
    }
}
