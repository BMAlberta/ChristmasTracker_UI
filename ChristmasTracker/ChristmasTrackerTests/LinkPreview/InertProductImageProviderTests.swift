//
//  InertProductImageProviderTests.swift
//  ChristmasTrackerTests
//
//  IMG1-P4: InertProductImageProvider always answers nil, including for the mock's known host.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("InertProductImageProvider", .timeLimit(.minutes(1)))
struct InertProductImageProviderTests {

    @Test("always nil", arguments: [
        "https://\(MockProductImageProvider.knownHost)/p/1",
        "https://shop.example.test/p/1",
        "http://shop.example.test/p/1",
        ""
    ])
    func alwaysNil(page: String) async throws {
        #expect(try await InertProductImageProvider().imageUrl(for: page) == nil)
    }
}
