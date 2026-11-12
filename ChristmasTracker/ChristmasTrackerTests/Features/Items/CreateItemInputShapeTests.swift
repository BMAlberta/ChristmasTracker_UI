//
//  CreateItemInputShapeTests.swift
//  ChristmasTrackerTests
//
//  Story I3c-B: the create request has no offList anywhere (the server derives it).
//  Checked two ways: the labels of a built value (Mirror) and a text scan of the
//  CreateItemInput declaration in Core/Models/ListItem.swift.
//

import Testing
import Foundation
@testable import ChristmasTracker

@Suite("CreateItemInput shape Tests")
struct CreateItemInputShapeTests {

    private func makeSUT() throws -> CreateItemInput {
        try #require(ItemFormValidation.makeCreateInput(
            name: "Fake Gift", description: "A fake description", url: "", imageUrl: "",
            priceText: "5", quantity: 1, priority: 5
        ))
    }

    @Test("A built CreateItemInput has exactly the seven documented members and no offList")
    func mirrorLabels() throws {
        let labels = Mirror(reflecting: try makeSUT()).children.compactMap(\.label)
        #expect(!labels.contains { $0.lowercased().contains("offlist") })
        #expect(Set(labels) == ["name", "description", "url", "imageUrl", "expectedUnitPrice",
                                "quantityRequested", "priority"])
    }

    @Test("The CreateItemInput declaration never mentions offList")
    func textScan() throws {
        let tree = try #require(ItemSourceTree.load(from: #filePath))
        let text = try #require(tree.source("Core/Models/ListItem.swift"), "Core/Models/ListItem.swift must exist")
        let code = ItemSourceScan.codeOnly(text)
        let body = try #require(ItemSourceScan.braceBody(after: "struct CreateItemInput", in: code),
                                "CreateItemInput declaration not found")
        #expect(try ItemSourceScan.matchingLines(#"(?i)\boffList\b"#, in: body).isEmpty)
    }
}
