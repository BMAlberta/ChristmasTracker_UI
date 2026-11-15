// UpdateInstallLinkTests.swift
// ChristmasTrackerTests
//
// Pure link builder (VER1 decision 2).

import Testing
import Foundation
@testable import ChristmasTracker

@Suite("UpdateInstallLink")
struct UpdateInstallLinkTests {

    private static let prefix = "itms-services://?action=download-manifest&url="

    private func encodedValue(of url: URL) -> String? {
        let raw = url.absoluteString
        guard raw.hasPrefix(Self.prefix) else { return nil }
        return String(raw.dropFirst(Self.prefix.count))
    }

    private func decodedInner(of url: URL) -> String? {
        URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "url" })?.value
    }

    // MARK: building

    @Test("a good https manifest builds the exact itms-services form")
    func goodHTTPSBuilds() {
        let url = UpdateInstallLink.url(from: "https://example.com/app/manifest.plist")
        #expect(url?.absoluteString ==
                "itms-services://?action=download-manifest&url=https%3A%2F%2Fexample.com%2Fapp%2Fmanifest.plist")
    }

    @Test("every reserved character in the manifest is percent-encoded in the value")
    func reservedCharactersEncoded() throws {
        let url = try #require(UpdateInstallLink.url(from: "https://example.com/a/m.plist?x=1&y=2#frag"))
        let value = try #require(encodedValue(of: url))
        for ch in [":", "/", "?", "#", "&", "=", "+", "@", "[", "]", " "] {
            #expect(!value.contains(ch), "value still contains \(ch)")
        }
        #expect(value.hasPrefix("https%3A%2F%2F"))
    }

    @Test("a manifest containing & = # ? and spaces round-trips through the encoding")
    func roundTrip() throws {
        let original = "https://example.com/my app/m.plist?a=b&c=d e#frag"
        let url = try #require(UpdateInstallLink.url(from: original))
        #expect(decodedInner(of: url) == original)
    }

    // MARK: already-built form

    @Test("the exact already-built itms-services form is returned unchanged")
    func alreadyBuiltUnchanged() {
        let input = Self.prefix + "https%3A%2F%2Fexample.com%2Fapp%2Fmanifest.plist"
        #expect(UpdateInstallLink.url(from: input)?.absoluteString == input)
    }

    @Test("itms-services in any other form is rejected", arguments: [
        "itms-services://?action=download&url=https%3A%2F%2Fexample.com%2Fm.plist",
        "itms-services://?action=download-manifest&url=https%3A%2F%2Fexample.com%2Fm.plist&extra=1",
        "itms-services://?action=download-manifest",
        "itms-services://?action=download-manifest&url=",
        "itms-services://?action=download-manifest&url=http%3A%2F%2Fexample.com%2Fm.plist",
        "itms-services://?url=https%3A%2F%2Fexample.com%2Fm.plist&action=download-manifest",
        "itms-services://?action=download-manifest&url=ftp%3A%2F%2Fexample.com%2Fm.plist",
        "itms-services://host?action=download-manifest&url=https%3A%2F%2Fexample.com%2Fm.plist",
    ])
    func otherItmsFormsRejected(input: String) {
        #expect(UpdateInstallLink.url(from: input) == nil)
    }

    @Test("an itms-services value whose inner manifest has userinfo is rejected")
    func itmsInnerUserinfoRejected() {
        let input = Self.prefix + "https%3A%2F%2Fuser%3Apw%40example.com%2Fm.plist"
        #expect(UpdateInstallLink.url(from: input) == nil)
    }

    @Test("itms-services with lowercase percent escapes is rejected (non-canonical)")
    func itmsLowercaseEscapesRejected() {
        let input = Self.prefix + "https%3a%2f%2fexample.com%2fm.plist"
        #expect(UpdateInstallLink.url(from: input) == nil)
    }

    @Test("itms-services with an unencoded inner URL is rejected")
    func itmsUnencodedInnerRejected() {
        let input = Self.prefix + "https://example.com/m.plist"
        #expect(UpdateInstallLink.url(from: input) == nil)
    }

    @Test("an uppercase ITMS-SERVICES scheme is rejected (never passed through)")
    func itmsUppercaseSchemeRejected() {
        let input = "ITMS-SERVICES://?action=download-manifest&url=https%3A%2F%2Fexample.com%2Fm.plist"
        #expect(UpdateInstallLink.url(from: input) == nil)
    }

    @Test("an itms-services link whose inner URL is over 2048 characters is rejected")
    func itmsInnerOverLengthRejected() {
        let head = "https://example.com/"
        let inner = head + String(repeating: "a", count: 2049 - head.count)
        #expect(inner.count == 2049)
        let input = Self.prefix + "https%3A%2F%2Fexample.com%2F" + String(repeating: "a", count: 2049 - head.count)
        #expect(UpdateInstallLink.url(from: input) == nil)
    }

    @Test("an itms-services link whose inner URL is exactly 2048 characters is accepted")
    func itmsInnerExactLengthAccepted() {
        let head = "https://example.com/"
        let input = Self.prefix + "https%3A%2F%2Fexample.com%2F" + String(repeating: "a", count: 2048 - head.count)
        #expect(UpdateInstallLink.url(from: input)?.absoluteString == input)
    }

    @Test("surrounding whitespace on an itms-services link is trimmed and the trimmed link returned")
    func itmsWhitespaceTrimmed() {
        let core = Self.prefix + "https%3A%2F%2Fexample.com%2Fm.plist"
        #expect(UpdateInstallLink.url(from: "  \n" + core + "\t ")?.absoluteString == core)
    }

    @Test("surrounding whitespace on an https manifest is trimmed and the link built")
    func httpsWhitespaceTrimmed() {
        let url = UpdateInstallLink.url(from: " \n https://example.com/m.plist \t")
        #expect(url?.absoluteString ==
                Self.prefix + "https%3A%2F%2Fexample.com%2Fm.plist")
    }

    // MARK: rejection

    @Test("an https manifest with an empty host is rejected", arguments: [
        "https://", "https:///m.plist", "https://?x=1", "https://#frag",
    ])
    func emptyHostRejected(input: String) {
        #expect(UpdateInstallLink.url(from: input) == nil)
    }

    @Test("userinfo placed right before a look-alike host is rejected", arguments: [
        "https://good.com@evil.com",
        "https://good.com@evil.com/m.plist",
    ])
    func lookAlikeUserinfoRejected(input: String) {
        #expect(UpdateInstallLink.url(from: input) == nil)
    }

    @Test("non-https schemes are rejected", arguments: [
        "http://example.com/m.plist",
        "ftp://example.com/m.plist",
        "javascript:alert(1)",
        "file:///etc/passwd",
        "example.com/m.plist",
    ])
    func wrongSchemeRejected(input: String) {
        #expect(UpdateInstallLink.url(from: input) == nil)
    }

    @Test("userinfo in the manifest is rejected", arguments: [
        "https://user@example.com/m.plist",
        "https://user:secret@example.com/m.plist",
    ])
    func userinfoRejected(input: String) {
        #expect(UpdateInstallLink.url(from: input) == nil)
    }

    @Test("nil, empty and whitespace-only inputs are rejected", arguments: [
        nil, "", "   ", "\n\t "
    ] as [String?])
    func emptyRejected(input: String?) {
        #expect(UpdateInstallLink.url(from: input) == nil)
    }

    // MARK: length

    private func manifest(ofLength length: Int) -> String {
        let head = "https://example.com/"
        return head + String(repeating: "a", count: length - head.count)
    }

    @Test("a manifest of exactly 2048 characters is accepted")
    func length2048Accepted() {
        let input = manifest(ofLength: 2048)
        #expect(input.count == 2048)
        #expect(UpdateInstallLink.url(from: input) != nil)
    }

    @Test("a manifest over 2048 characters is rejected")
    func length2049Rejected() {
        let input = manifest(ofLength: 2049)
        #expect(input.count == 2049)
        #expect(UpdateInstallLink.url(from: input) == nil)
    }
}
