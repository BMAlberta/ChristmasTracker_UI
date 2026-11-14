//
//  PurchaseDeleteRefreshPlanTests.swift
//  ChristmasTrackerTests
//
//  Story I4b-A: the refreshes after deleting a purchase are exactly the I4a plan.
//
//  EDITED (I5a-B): both plans gained the same final `.invalidateSpending` step; the equality between
//  the two plans stays, and the concrete arrays only gained that appended step.
//
//  Fails today because PurchaseRefreshPlan.stepsAfterDelete does not exist yet.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("Purchase delete refresh plan Tests")
struct PurchaseDeleteRefreshPlanTests {

    @Test("The plan after a delete equals the I4a plan",
          arguments: [nil, "list-1", "list-OTHER"] as [String?])
    func equalsRecordPlan(current: String?) {
        let afterDelete = PurchaseRefreshPlan.stepsAfterDelete(itemId: "item-1", listId: "list-1", currentItemsListId: current)
        let afterRecord = PurchaseRefreshPlan.steps(itemId: "item-1", listId: "list-1", currentItemsListId: current)
        #expect(afterDelete == afterRecord)
    }

    @Test("Same list refreshes in place, another list loads; ids are carried; the invalidation is last")
    func concreteSteps() {
        #expect(PurchaseRefreshPlan.stepsAfterDelete(itemId: "item-ZZ", listId: "list-QQ", currentItemsListId: "list-QQ")
                == [.itemDetail(id: "item-ZZ"), .itemsRefresh, .listDetail(id: "list-QQ"), .invalidateSpending])
        #expect(PurchaseRefreshPlan.stepsAfterDelete(itemId: "item-ZZ", listId: "list-QQ", currentItemsListId: nil)
                == [.itemDetail(id: "item-ZZ"), .itemsLoad(listId: "list-QQ"), .listDetail(id: "list-QQ"), .invalidateSpending])
    }

    @Test("A plan after a delete ends with the spending invalidation and holds it once",
          arguments: [nil, "list-1", "list-OTHER"] as [String?])
    func endsWithInvalidation(current: String?) {
        let steps = PurchaseRefreshPlan.stepsAfterDelete(itemId: "item-1", listId: "list-1", currentItemsListId: current)

        #expect(steps.last == .invalidateSpending)
        #expect(steps.filter { $0 == .invalidateSpending }.count == 1)
        #expect(steps.count == 4)
    }
}
