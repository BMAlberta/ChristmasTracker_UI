//
//  ProductImageURLNormalizerTests.swift
//  ChristmasTrackerTests
//
//  IMG1-P4 (decision 13): the normalization table. http is upgraded to https (same host, path, query);
//  https is unchanged; every other scheme, userinfo, more than 2048 characters (after the upgrade),
//  whitespace or control characters, a missing host, nil and empty are rejected.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("ProductImageURLNormalizer", .timeLimit(.minutes(1)))
struct ProductImageURLNormalizerTests {

    private static let host = "https://images.example.test/"

    /// A string of exactly `length` characters that starts with `prefix`.
    static func padded(_ prefix: String, to length: Int) -> String {
        prefix + String(repeating: "a", count: length - prefix.count)
    }

    static let accepted: [(raw: String, expected: String)] = [
        ("https://images.example.test/a.jpg", "https://images.example.test/a.jpg"),
        ("https://images.example.test/a/b.jpg?w=200&h=100", "https://images.example.test/a/b.jpg?w=200&h=100"),
        ("http://images.example.test/a.jpg", "https://images.example.test/a.jpg"),
        ("http://images.example.test/a/b.jpg?w=200&h=100", "https://images.example.test/a/b.jpg?w=200&h=100"),
        ("http://images.example.test:8080/a.jpg", "https://images.example.test:8080/a.jpg"),
        // https at exactly 2048 stays; http at 2047 becomes exactly 2048.
        (padded("https://images.example.test/", to: 2048), padded("https://images.example.test/", to: 2048)),
        (padded("http://images.example.test/", to: 2047), padded("https://images.example.test/", to: 2048))
    ]

    static let rejected: [String] = [
        "ftp://images.example.test/a.jpg",
        "javascript:alert(1)",
        "file:///etc/a.jpg",
        "data:image/png;base64,AAAA",
        "blob:https://images.example.test/a",
        "https://user@images.example.test/a.jpg",
        "https://user:pw@images.example.test/a.jpg",
        "http://user:pw@images.example.test/a.jpg",
        "https://images.example.test/a b.jpg",
        "https://images.example.test/a\tb.jpg",
        "https://images.example.test/a\nb.jpg",
        " https://images.example.test/a.jpg",
        "https://images.example.test/a.jpg ",
        "https://images.example.test/a\u{0000}b.jpg",
        "https:///a.jpg",
        "https://",
        "http://",
        "//images.example.test/a.jpg",
        "images.example.test/a.jpg",
        "",
        padded("https://images.example.test/", to: 2049),
        padded("https://images.example.test/", to: 2100),
        // http at 2048 is 2049 once upgraded.
        padded("http://images.example.test/", to: 2048)
    ]

    @Test("an accepted value is returned (http upgraded to https)", arguments: accepted)
    func acceptedValue(raw: String, expected: String) {
        #expect(ProductImageURLNormalizer.normalized(raw) == expected)
    }

    @Test("a rejected value is nil", arguments: rejected)
    func rejectedValue(raw: String) {
        #expect(ProductImageURLNormalizer.normalized(raw) == nil)
    }

    @Test("nil is nil")
    func nilInput() {
        #expect(ProductImageURLNormalizer.normalized(nil) == nil)
    }

    @Test("the upgrade keeps host, path and query")
    func upgradeKeepsParts() throws {
        let result = try #require(ProductImageURLNormalizer.normalized("http://cdn.example.test/p/1/img.png?v=3&s=big"))
        let components = try #require(URLComponents(string: result))

        #expect(components.scheme == "https")
        #expect(components.host == "cdn.example.test")
        #expect(components.path == "/p/1/img.png")
        #expect(components.query == "v=3&s=big")
    }
}
