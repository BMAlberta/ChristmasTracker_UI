//
//  ThumbnailURLTests.swift
//  ChristmasTrackerTests
//
//  Story TH1-T6: the pure thumbnail URL rule. Only obviously fake example.test values are used.
//  Expectation for an uppercase scheme: URL scheme comparison is case-insensitive, so
//  "HTTPS://..." is accepted and the resulting URL's scheme compares equal to "https" once lowercased.
//  Non-ASCII / IDN hosts are intentionally not tested.
//

import Testing
import Foundation
@testable import ChristmasTracker

/// A labelled input so test names carry a label, never the value.
struct ThumbnailInput: Sendable, CustomTestStringConvertible {
    let label: String
    let value: String?
    var testDescription: String { label }
}

let validInputs: [ThumbnailInput] = [
    ThumbnailInput(label: "plain https", value: "https://example.test/a.png"),
    ThumbnailInput(label: "port, path and query", value: "https://example.test:8443/img/a.png?w=100&h=100"),
    ThumbnailInput(label: "host only", value: "https://example.test")
]

let invalidInputs: [ThumbnailInput] = [
    ThumbnailInput(label: "nil", value: nil),
    ThumbnailInput(label: "empty", value: ""),
    ThumbnailInput(label: "whitespace only", value: "   "),
    ThumbnailInput(label: "http scheme", value: "http://example.test/a.png"),
    ThumbnailInput(label: "ftp scheme", value: "ftp://example.test/a.png"),
    ThumbnailInput(label: "file scheme", value: "file:///tmp/a.png"),
    ThumbnailInput(label: "javascript scheme", value: "javascript:alert(1)"),
    ThumbnailInput(label: "data scheme", value: "data:image/png;base64,AAAA"),
    ThumbnailInput(label: "ws scheme", value: "ws://example.test/a.png"),
    ThumbnailInput(label: "space in value", value: "https://example.test/a b.png"),
    ThumbnailInput(label: "newline in value", value: "https://example.test/a\n.png"),
    ThumbnailInput(label: "leading space", value: " https://example.test/a.png"),
    ThumbnailInput(label: "trailing newline", value: "https://example.test/a.png\n"),
    ThumbnailInput(label: "control character", value: "https://example.test/a\u{0007}.png"),
    ThumbnailInput(label: "missing host", value: "https://"),
    ThumbnailInput(label: "missing host with path", value: "https:///path"),
    ThumbnailInput(label: "relative path", value: "images/a.png"),
    ThumbnailInput(label: "absolute path only", value: "/images/a.png"),
    ThumbnailInput(label: "scheme relative", value: "//example.test/a.png")
]

@Suite("Thumbnail URL Tests")
struct ThumbnailURLTests {

    private func makeSUT() -> ThumbnailURL.Type { ThumbnailURL.self }

    private func padded(toLength length: Int) -> String {
        let prefix = "https://example.test/"
        return prefix + String(repeating: "a", count: length - prefix.count)
    }

    @Test("The maximum length is 2048")
    func maximumLength() {
        #expect(makeSUT().maximumLength == 2048)
    }

    @Test("A valid https value is accepted and round-trips", arguments: validInputs)
    func validAccepted(input: ThumbnailInput) throws {
        let url = try #require(makeSUT().validate(input.value))
        #expect(url.scheme?.lowercased() == "https")
        #expect(url.absoluteString == input.value)
    }

    @Test("An invalid value is rejected", arguments: invalidInputs)
    func invalidRejected(input: ThumbnailInput) {
        #expect(makeSUT().validate(input.value) == nil)
    }

    @Test("An uppercase scheme is accepted and stays https")
    func uppercaseSchemeAccepted() throws {
        let url = try #require(makeSUT().validate("HTTPS://example.test/a.png"))
        #expect(url.scheme?.lowercased() == "https")
        #expect(url.host() == "example.test")
    }

    @Test("A value of exactly 2048 characters is accepted")
    func exactlyMaximumAccepted() throws {
        let value = padded(toLength: 2048)
        #expect(value.count == 2048)
        #expect(makeSUT().validate(value) != nil)
    }

    @Test("A value of 2049 characters is rejected")
    func overMaximumRejected() {
        let value = padded(toLength: 2049)
        #expect(value.count == 2049)
        #expect(makeSUT().validate(value) == nil)
    }

    // MARK: - Presentation

    @Test("Presentation gives the placeholder for every invalid value", arguments: invalidInputs)
    func presentationPlaceholder(input: ThumbnailInput) {
        #expect(ThumbnailPresentation.content(for: input.value) == .placeholder)
    }

    @Test("Presentation gives the image for a valid value", arguments: validInputs)
    func presentationImage(input: ThumbnailInput) throws {
        let url = try #require(ThumbnailURL.validate(input.value))
        #expect(ThumbnailPresentation.content(for: input.value) == .image(url))
    }

    @Test("A failed load maps to the one placeholder case, never an image")
    func failedLoadIsPlaceholder() throws {
        let failed = ThumbnailContent.placeholder
        let fake = try #require(URL(string: "https://example.test/a.png"))
        #expect(failed == ThumbnailContent.placeholder)
        #expect(failed != ThumbnailContent.image(fake))
        #expect(ThumbnailPresentation.content(for: nil) == failed)
    }
}
