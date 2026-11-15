//
//  ProductImageMetadataReaderTests.swift
//  ChristmasTrackerTests
//
//  IMG1-P4 (decision 13): the pure guarded two-hop extraction, against fake NSObject subclasses. Every
//  hop is guarded by responds(to:), so a missing selector, a nil value or a value of the wrong type
//  returns nil and never raises an Objective-C exception (a raise would crash this test process).
//
//  The second-hop selector is named "URL"; the fakes declare it with @objc(URL) on a differently named
//  Swift property so it does not clash with Foundation.URL.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("ProductImageMetadataReader", .timeLimit(.minutes(1)))
struct ProductImageMetadataReaderTests {

    private static let imageString = "https://images.example.test/device.jpg?w=2"

    private func url(_ string: String) throws -> URL {
        try #require(URL(string: string))
    }

    @Test("both selectors present: the URL's absolute string")
    func bothHops() throws {
        let metadata = FakeLinkMetadataWithImage(FakeImageMetadataWithURL(try url(Self.imageString)))

        #expect(ProductImageMetadataReader.imageURLString(from: metadata) == Self.imageString)
    }

    @Test("the string is returned as is, with no validation (http stays http here)")
    func noValidationHere() throws {
        let metadata = FakeLinkMetadataWithImage(FakeImageMetadataWithURL(try url("http://images.example.test/a.jpg")))

        #expect(ProductImageMetadataReader.imageURLString(from: metadata) == "http://images.example.test/a.jpg")
    }

    @Test("an object without the first selector gives nil")
    func missingFirstSelector() {
        #expect(ProductImageMetadataReader.imageURLString(from: NSObject()) == nil)
    }

    @Test("an object without the first selector gives nil even when it has the second one")
    func missingFirstButHasSecond() throws {
        let metadata = FakeImageMetadataWithURL(try url(Self.imageString))

        #expect(ProductImageMetadataReader.imageURLString(from: metadata) == nil)
    }

    @Test("a second object without the second selector gives nil")
    func missingSecondSelector() {
        let metadata = FakeLinkMetadataWithImage(NSObject())

        #expect(ProductImageMetadataReader.imageURLString(from: metadata) == nil)
    }

    @Test("a nil image metadata gives nil")
    func nilFirstValue() {
        #expect(ProductImageMetadataReader.imageURLString(from: FakeLinkMetadataWithImage(nil)) == nil)
    }

    @Test("a nil URL gives nil")
    func nilSecondValue() {
        let metadata = FakeLinkMetadataWithImage(FakeImageMetadataWithURL(nil))

        #expect(ProductImageMetadataReader.imageURLString(from: metadata) == nil)
    }

    @Test("a non-URL value gives nil", arguments: [
        "https://images.example.test/a.jpg" as Any,
        NSNumber(value: 42) as Any,
        Data([1, 2, 3]) as Any,
        NSObject() as Any
    ])
    func nonURLValue(value: Any) {
        let metadata = FakeLinkMetadataWithImage(FakeImageMetadataWithURL(value))

        #expect(ProductImageMetadataReader.imageURLString(from: metadata) == nil)
    }
}
