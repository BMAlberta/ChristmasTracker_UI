//
//  ListScreenExitGoneListTests.swift
//  ChristmasTrackerTests
//
//  Story I3b-K0 (F5): the screen leaves when the service reports THIS list as gone, never
//  because of another list's gone error. Truth table: nil, same id, different id.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("ListScreenExit gone-list Tests")
struct ListScreenExitGoneListTests {

    @Test("shouldDismissDetail(goneListId:openListId:) is true only when the ids are equal")
    func detailTruthTable() {
        #expect(ListScreenExit.shouldDismissDetail(goneListId: nil, openListId: "list-a") == false)
        #expect(ListScreenExit.shouldDismissDetail(goneListId: "list-a", openListId: "list-a") == true)
        #expect(ListScreenExit.shouldDismissDetail(goneListId: "list-b", openListId: "list-a") == false)
    }

    @Test("shouldDismissEdit(goneListId:editedListId:) is true only when the ids are equal")
    func editTruthTable() {
        #expect(ListScreenExit.shouldDismissEdit(goneListId: nil, editedListId: "list-a") == false)
        #expect(ListScreenExit.shouldDismissEdit(goneListId: "list-a", editedListId: "list-a") == true)
        #expect(ListScreenExit.shouldDismissEdit(goneListId: "list-b", editedListId: "list-a") == false)
    }
}
