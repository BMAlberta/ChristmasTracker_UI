//
//  LinkPreviewInputTests.swift
//  ChristmasTrackerTests
//
//  IMG1-P1: LinkPreviewInput.validated accepts http or https with a host, no userinfo, at most 2048
//  characters and no whitespace; everything else is nil.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("LinkPreviewInput", .timeLimit(.minutes(1)))
struct LinkPreviewInputTests {

    private static func padded(to length: Int, scheme: String = "https") -> String {
        let prefix = "\(scheme)://shop.example.test/"
        return prefix + String(repeating: "a", count: length - prefix.count)
    }

    @Test("a valid http or https URL is returned unchanged", arguments: [
        "https://shop.example.test/p/1",
        "http://shop.example.test/p/1",
        "https://shop.example.test",
        "https://shop.example.test:8443/p?x=1&y=2#frag"
    ])
    func accepted(value: String) {
        #expect(LinkPreviewInput.validated(value) == value)
    }

    @Test("a URL of exactly 2048 characters is accepted")
    func atLimit() {
        let value = Self.padded(to: 2048)
        #expect(value.count == 2048)
        #expect(LinkPreviewInput.validated(value) == value)
    }

    @Test("a URL of 2049 characters is rejected")
    func overLimit() {
        let value = Self.padded(to: 2049)
        #expect(value.count == 2049)
        #expect(LinkPreviewInput.validated(value) == nil)
    }

    @Test("these inputs are rejected", arguments: [
        "",
        "ftp://shop.example.test/p",
        "javascript:alert(1)",
        "file:///etc/passwd",
        "shop.example.test/p",
        "https://",
        "https:///path",
        "http://",
        "https://user@shop.example.test/p",
        "https://user:pw@shop.example.test/p",
        "https://shop.example.test/a b",
        "https://shop.example.test/a\tb",
        "https://shop.example.test/a\nb"
    ])
    func rejected(value: String) {
        #expect(LinkPreviewInput.validated(value) == nil)
    }
}
