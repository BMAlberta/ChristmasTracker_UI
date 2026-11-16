//
//  LinkPresentationProductImageProviderTests.swift
//  ChristmasTrackerTests
//
//  IMG1-P4 (decision 11): the real LinkPresentation provider is never constructed or run in tests (it
//  would reach the network). Only its constant is pinned here; its source is pinned by
//  ProductImageProviderSourceScanTests.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("LinkPresentationProductImageProvider constants", .timeLimit(.minutes(1)))
struct LinkPresentationProductImageProviderTests {

    @Test("the fetch timeout is 8 seconds")
    func timeout() {
        #expect(LinkPresentationProductImageProvider.timeout == 8)
    }
}
