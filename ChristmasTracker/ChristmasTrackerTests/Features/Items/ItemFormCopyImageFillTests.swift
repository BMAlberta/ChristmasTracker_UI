//
//  ItemFormCopyImageFillTests.swift
//  ChristmasTrackerTests
//
//  IMG1-P3: the static copy the link-preview form behavior uses.
//
//  Covers ItemFormCopy.
//

import Testing
@testable import ChristmasTracker

@Suite("Item form copy (image fill) Tests")
struct ItemFormCopyImageFillTests {

    @Test("The invalid url line is the pinned sentence")
    func invalidUrl() {
        #expect(ItemFormCopy.invalidUrl == "Enter a web address that starts with http:// or https://.")
    }

    @Test("The invalid image url line is the pinned sentence")
    func invalidImageUrl() {
        #expect(ItemFormCopy.invalidImageUrl == "The image address must start with https://.")
    }

    @Test("The spinner accessibility label is the pinned text")
    func lookingForImage() {
        #expect(ItemFormCopy.lookingForImage == "Looking for a product image")
    }

    @Test("Every new line is non-empty")
    func nonEmpty() {
        #expect(!ItemFormCopy.invalidUrl.isEmpty)
        #expect(!ItemFormCopy.invalidImageUrl.isEmpty)
        #expect(!ItemFormCopy.lookingForImage.isEmpty)
    }
}
