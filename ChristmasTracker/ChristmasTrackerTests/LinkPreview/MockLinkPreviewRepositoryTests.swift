//
//  MockLinkPreviewRepositoryTests.swift
//  ChristmasTrackerTests
//
//  IMG1-P1: the mock returns fixedImageUrl when the page URL's host equals knownHost, nil for
//  everything else. No network.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("MockLinkPreviewRepository", .timeLimit(.minutes(1)))
struct MockLinkPreviewRepositoryTests {

    private func makeSUT() -> MockLinkPreviewRepository {
        MockLinkPreviewRepository()
    }

    @Test("the fixture constants are the documented ones")
    func constants() {
        #expect(MockLinkPreviewRepository.knownHost == "shop.example.test")
        #expect(MockLinkPreviewRepository.fixedImageUrl == "https://images.example.test/preview.jpg")
    }

    @Test("a URL on the known host returns the fixed image", arguments: [
        "https://shop.example.test/p/1",
        "http://shop.example.test/p/1",
        "https://shop.example.test"
    ])
    func knownHost(url: String) async throws {
        let result = try await makeSUT().imageUrl(for: url)
        #expect(result == MockLinkPreviewRepository.fixedImageUrl)
    }

    @Test("any other host, a look-alike host or an unparseable string returns nil", arguments: [
        "https://other.example.test/p/1",
        "https://www.shop.example.test/p/1",
        "https://notshop.example.test/p/1",
        "https://shop.example.test.evil.test/p/1",
        "https://other.example.test/shop.example.test",
        "",
        "not a url"
    ])
    func otherHost(url: String) async throws {
        let result = try await makeSUT().imageUrl(for: url)
        #expect(result == nil)
    }

    @Test("it conforms to LinkPreviewLoading")
    func conforms() {
        let loader: any LinkPreviewLoading = makeSUT()
        #expect(loader is MockLinkPreviewRepository)
    }
}
