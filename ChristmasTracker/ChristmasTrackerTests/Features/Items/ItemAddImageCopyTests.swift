//
//  ItemAddImageCopyTests.swift
//  ChristmasTrackerTests
//
//  IMG1-P5 (decision 16): the exact user-facing copy of the "Add image" action.
//
//  Covers ItemFormCopy.addImageTitle, addImageHint and addImageFailure.
//

import Testing
import Foundation
@testable import ChristmasTracker

@Suite("Item add image copy Tests")
struct ItemAddImageCopyTests {

    @Test("The title is exact")
    func title() {
        #expect(ItemFormCopy.addImageTitle == "Add image")
    }

    @Test("The hint is exact")
    func hint() {
        #expect(ItemFormCopy.addImageHint == "Looks for a picture on the product page.")
    }

    @Test("The failure line is exact and uses a straight apostrophe")
    func failure() {
        #expect(ItemFormCopy.addImageFailure == "Couldn't find an image for this link.")
        #expect(!ItemFormCopy.addImageFailure.contains("\u{2019}"))
    }

    @Test("None of the strings is empty")
    func nonEmpty() {
        #expect(!ItemFormCopy.addImageTitle.isEmpty)
        #expect(!ItemFormCopy.addImageHint.isEmpty)
        #expect(!ItemFormCopy.addImageFailure.isEmpty)
    }
}
