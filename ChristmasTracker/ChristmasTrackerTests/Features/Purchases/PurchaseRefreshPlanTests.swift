//
//  PurchaseRefreshPlanTests.swift
//  ChristmasTrackerTests
//
//  Story I4a-C (a): PurchaseRefreshPlan lists refreshes only, always three steps in the order
//  itemDetail, then itemsRefresh or itemsLoad, then listDetail. It carries no count, status or
//  quantity (mock mode does not change items after a purchase; a real server may not either).
//
//  Fails today because PurchaseRefreshPlan and PurchaseRefreshStep do not exist yet.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("Purchase refresh plan Tests")
struct PurchaseRefreshPlanTests {

    private func makeSUT(itemId: String = "item-1", listId: String = "list-1", current: String?) -> [PurchaseRefreshStep] {
        PurchaseRefreshPlan.steps(itemId: itemId, listId: listId, currentItemsListId: current)
    }

    @Test("When the item service holds this list the plan refreshes the items in place")
    func sameList() {
        #expect(makeSUT(current: "list-1") == [
            .itemDetail(id: "item-1"), .itemsRefresh, .listDetail(id: "list-1")
        ])
    }

    @Test("When the item service holds another list the plan loads this list's items")
    func otherList() {
        #expect(makeSUT(current: "list-OTHER") == [
            .itemDetail(id: "item-1"), .itemsLoad(listId: "list-1"), .listDetail(id: "list-1")
        ])
    }

    @Test("When the item service holds no list the plan loads this list's items")
    func noCurrentList() {
        #expect(makeSUT(current: nil) == [
            .itemDetail(id: "item-1"), .itemsLoad(listId: "list-1"), .listDetail(id: "list-1")
        ])
    }

    @Test("The plan always has three steps, detail first and list detail last", arguments: [nil, "list-1", "list-2"] as [String?])
    func shape(current: String?) {
        let steps = makeSUT(current: current)
        #expect(steps.count == 3)
        #expect(steps.first == .itemDetail(id: "item-1"))
        #expect(steps.last == .listDetail(id: "list-1"))
    }

    @Test("The ids come from the arguments and are not swapped")
    func idsAreCarried() {
        let steps = makeSUT(itemId: "item-ZZ", listId: "list-QQ", current: nil)
        #expect(steps == [.itemDetail(id: "item-ZZ"), .itemsLoad(listId: "list-QQ"), .listDetail(id: "list-QQ")])
    }

    @Test("The plan is a pure function: equal inputs give equal plans")
    func isPure() {
        #expect(makeSUT(current: "list-1") == makeSUT(current: "list-1"))
    }

    @Test("A step is only a refresh: its cases carry ids and nothing else")
    func stepsCarryNoData() {
        let all: [PurchaseRefreshStep] = makeSUT(current: nil) + makeSUT(current: "list-1")
        for step in all {
            let text = String(describing: step).lowercased()
            for forbidden in ["status", "count", "quantity", "remaining", "purchased"] {
                #expect(!text.contains(forbidden), "\(step)")
            }
        }
    }
}
