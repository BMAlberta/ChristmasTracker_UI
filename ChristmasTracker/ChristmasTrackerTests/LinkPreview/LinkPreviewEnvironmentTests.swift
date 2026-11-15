//
//  LinkPreviewEnvironmentTests.swift
//  ChristmasTrackerTests
//
//  IMG1-P1: the SwiftUI environment default of LinkPreviewService (EnvironmentValues.linkPreviewService)
//  is built from an inert loader: it never reaches a network or a mock and always returns nil.
//

import Foundation
import SwiftUI
import Testing
@testable import ChristmasTracker

@Suite("LinkPreviewService environment default", .timeLimit(.minutes(1)))
@MainActor
struct LinkPreviewEnvironmentTests {

    private func makeSUT() -> LinkPreviewService {
        EnvironmentValues().linkPreviewService
    }

    @Test("the default service returns nil for a valid URL")
    func defaultReturnsNil() async {
        let result = await makeSUT().imageUrl(for: "https://shop.example.test/p/1")
        #expect(result == nil, "the inert default must not return the mock fixture")
    }

    @Test("the default service returns nil for an invalid URL")
    func defaultReturnsNilForInvalid() async {
        #expect(await makeSUT().imageUrl(for: "") == nil)
    }

    @Test("the default service can be cleared without error")
    func defaultClears() async throws {
        let service = makeSUT()
        let before = service.sessionGeneration

        try await service.clearForSession()

        #expect(service.sessionGeneration != before)
    }
}
