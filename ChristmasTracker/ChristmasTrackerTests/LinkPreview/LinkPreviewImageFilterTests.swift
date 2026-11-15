//
//  LinkPreviewImageFilterTests.swift
//  ChristmasTrackerTests
//
//  IMG1-P1 (decision 6): a returned image value is accepted only if ThumbnailURL.validate accepts it
//  (https, host, at most 2048, no whitespace) AND it has no userinfo; otherwise nil.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("LinkPreviewImageFilter", .timeLimit(.minutes(1)))
struct LinkPreviewImageFilterTests {

    @Test("a good https value is accepted unchanged", arguments: [
        "https://images.example.test/a.jpg",
        "https://images.example.test/a.jpg?w=200&h=100",
        "https://images.example.test:8443/a.jpg"
    ])
    func accepted(value: String) {
        #expect(LinkPreviewImageFilter.accepted(value) == value)
    }

    @Test("nil stays nil")
    func nilInput() {
        #expect(LinkPreviewImageFilter.accepted(nil) == nil)
    }

    @Test("these values are rejected", arguments: [
        "",
        "http://images.example.test/a.jpg",
        "ftp://images.example.test/a.jpg",
        "https:///a.jpg",
        "https://user@images.example.test/a.jpg",
        "https://user:pw@images.example.test/a.jpg",
        "https://images.example.test/a b.jpg",
        "https://images.example.test/a\tb.jpg",
        "https://images.example.test/a\nb.jpg",
        "not a url"
    ])
    func rejected(value: String) {
        #expect(LinkPreviewImageFilter.accepted(value) == nil)
    }

    @Test("2048 characters is accepted, 2049 is rejected")
    func lengthBoundary() {
        let prefix = "https://images.example.test/"
        let atLimit = prefix + String(repeating: "a", count: 2048 - prefix.count)
        let over = prefix + String(repeating: "a", count: 2049 - prefix.count)

        #expect(LinkPreviewImageFilter.accepted(atLimit) == atLimit)
        #expect(LinkPreviewImageFilter.accepted(over) == nil)
    }
}
