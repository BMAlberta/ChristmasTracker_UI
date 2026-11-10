//
//  ListDataStoreTests.swift
//  ChristmasTrackerTests
//
//  Story I3a-L2 fix round: ListDataStore.storeCreated(_:) is ONE atomic actor method that caches
//  the detail and upserts its summary in a single hop. Will not compile until it exists.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("ListDataStore")
struct ListDataStoreTests {

    private let editable = ListFixtures.Flags(canEditList: true, canDeleteList: true, canManageMembers: true)

    @Test("storeCreated caches the detail and appends its summary when the list is new")
    func storeCreatedAppendsNewList() async {
        let store = ListDataStore()
        await store.setLists([ListFixtures.giftList(id: "list-a", name: "Alpha")])
        let created = ListFixtures.listDetail(id: "list-new", name: "Brand New", flags: editable, memberCount: 1)

        await store.storeCreated(created)

        let detail = await store.getListDetail(id: "list-new")
        let lists = await store.getLists()
        #expect(detail == created)
        #expect(lists.map(\.id) == ["list-a", "list-new"])
        #expect(lists.last == created.asGiftList())
    }

    @Test("storeCreated on an empty store caches both the detail and the summary")
    func storeCreatedOnEmptyStore() async {
        let store = ListDataStore()
        let created = ListFixtures.listDetail(id: "list-new", name: "Brand New", flags: editable)

        await store.storeCreated(created)

        let detail = await store.getListDetail(id: "list-new")
        let lists = await store.getLists()
        #expect(detail == created)
        #expect(lists == [created.asGiftList()])
    }

    @Test("storeCreated replaces an existing summary with the same id, in place")
    func storeCreatedReplacesExistingSummary() async {
        let store = ListDataStore()
        await store.setLists([
            ListFixtures.giftList(id: "list-a", name: "Alpha"),
            ListFixtures.giftList(id: "list-b", name: "Beta")
        ])
        let replacement = ListFixtures.listDetail(id: "list-a", name: "Alpha Again", flags: editable)

        await store.storeCreated(replacement)

        let lists = await store.getLists()
        let detail = await store.getListDetail(id: "list-a")
        #expect(lists.map(\.id) == ["list-a", "list-b"], "no duplicate, order kept")
        #expect(lists.first == replacement.asGiftList())
        #expect(detail == replacement)
    }

    @Test("storeCreated does not touch other cached lists or details")
    func storeCreatedLeavesOthersAlone() async {
        let store = ListDataStore()
        let other = ListFixtures.listDetail(id: "list-b", name: "Beta")
        await store.setLists([ListFixtures.giftList(id: "list-b", name: "Beta")])
        await store.setListDetail(other)

        await store.storeCreated(ListFixtures.listDetail(id: "list-new", name: "Brand New"))

        let otherDetail = await store.getListDetail(id: "list-b")
        #expect(otherDetail == other)
    }

    @Test("a cleared store holds nothing from storeCreated")
    func clearRemovesStoredCreation() async {
        let store = ListDataStore()
        await store.storeCreated(ListFixtures.listDetail(id: "list-new", name: "Brand New"))

        await store.clear()

        let lists = await store.getLists()
        let detail = await store.getListDetail(id: "list-new")
        #expect(lists.isEmpty)
        #expect(detail == nil)
    }
}
