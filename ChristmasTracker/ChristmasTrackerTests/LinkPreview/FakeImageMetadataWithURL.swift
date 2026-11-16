//
//  FakeImageMetadataWithURL.swift
//  ChristmasTrackerTests
//
//  IMG1-P4: stands in for the second object (the image metadata): answers the "URL" selector with any
//  value. Declared with @objc(URL) on a differently named property so it does not clash with
//  Foundation.URL.
//

import Foundation

nonisolated final class FakeImageMetadataWithURL: NSObject {
    @objc(URL) let urlValue: Any?
    init(_ value: Any?) { urlValue = value }
}
