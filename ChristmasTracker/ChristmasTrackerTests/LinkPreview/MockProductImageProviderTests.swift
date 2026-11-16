//
//  MockProductImageProviderTests.swift
//  ChristmasTrackerTests
//
//  IMG1-P4: MockProductImageProvider answers a fixed https image for its known host (http or https
//  page URL) and nil for everything else. No network.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("MockProductImageProvider", .timeLimit(.minutes(1)))
struct MockProductImageProviderTests {

    private func makeSUT() -> MockProductImageProvider { MockProductImageProvider() }

    @Test("the constants")
    func constants() {
        #expect(MockProductImageProvider.knownHost == "device.example.test")
        #expect(MockProductImageProvider.fixedImageUrl == "https://images.example.test/device.jpg")
    }

    @Test("the known host returns the fixed image for http and https", arguments: [
        "https://device.example.test/p/1",
        "http://device.example.test/p/1",
        "https://device.example.test/",
        "https://device.example.test/p/1?x=1"
    ])
    func knownHost(page: String) async throws {
        let result = try await makeSUT().imageUrl(for: page)

        #expect(result == MockProductImageProvider.fixedImageUrl)
    }

    @Test("the fixed image is an https value the filter accepts")
    func fixedImageIsAccepted() {
        #expect(LinkPreviewImageFilter.accepted(MockProductImageProvider.fixedImageUrl) != nil)
    }

    @Test("any other page returns nil", arguments: [
        "https://other.example.test/p/1",
        "https://shop.example.test/p/1",
        "https://notdevice.example.test/p/1",
        "https://device.example.test.evil.test/p/1",
        "not a url",
        ""
    ])
    func otherHost(page: String) async throws {
        #expect(try await makeSUT().imageUrl(for: page) == nil)
    }
}
