//
//  FakeLinkMetadataWithImage.swift
//  ChristmasTrackerTests
//
//  IMG1-P4: stands in for the link metadata object: answers the "imageMetadata" selector with any
//  object.
//

import Foundation

nonisolated final class FakeLinkMetadataWithImage: NSObject {
    @objc let imageMetadata: NSObject?
    init(_ value: NSObject?) { imageMetadata = value }
}
