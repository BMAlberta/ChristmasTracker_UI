//
//  LinkPreviewWiringProviderTests.swift
//  ChristmasTrackerTests
//
//  IMG1-P4: makeLinkPreviewService picks the device provider, observed only through behavior (the real
//  LinkPresentation provider is never constructed here):
//   - mock mode + .ready: the mock provider answers for MockProductImageProvider.knownHost (the API mock
//     returns nil for that host, so the answer is the device image);
//   - a failed bootstrap and real mode without a client are inert: nil for the same page.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("Link preview wiring: device provider", .timeLimit(.minutes(1)))
@MainActor
struct LinkPreviewWiringProviderTests {

    private static let devicePage = "https://\(MockProductImageProvider.knownHost)/p/1"
    private static let otherPage = "https://other.example.test/p/1"

    @Test("the API mock has no image for the device host, so the test really reaches the provider")
    func apiMockHasNothing() async throws {
        #expect(try await MockLinkPreviewRepository().imageUrl(for: Self.devicePage) == nil)
    }

    @Test("mock mode returns the mock provider's image for its known host")
    func mockMode() async {
        let service = makeLinkPreviewService(mode: .mock, state: .ready, client: nil)

        #expect(await service.imageUrl(for: Self.devicePage) == MockProductImageProvider.fixedImageUrl)
    }

    @Test("mock mode returns nil for any other host")
    func mockModeOtherHost() async {
        let service = makeLinkPreviewService(mode: .mock, state: .ready, client: nil)

        #expect(await service.imageUrl(for: Self.otherPage) == nil)
    }

    @Test("a failed bootstrap is inert for the device host, in either mode", arguments: [APIMode.mock, APIMode.real])
    func failedIsInert(mode: APIMode) async {
        let service = makeLinkPreviewService(mode: mode, state: .failed, client: nil)

        #expect(await service.imageUrl(for: Self.devicePage) == nil)
    }

    @Test("real mode with no client is inert for the device host")
    func realModeWithoutClient() async {
        let service = makeLinkPreviewService(mode: .real, state: .ready, client: nil)

        #expect(await service.imageUrl(for: Self.devicePage) == nil)
    }
}
