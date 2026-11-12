//
//  RecordPurchaseVisibilityTests.swift
//  ChristmasTrackerTests
//
//  Story I4a-C (d): who sees the purchase entry, the form and the quantities, for every persona
//  on an ACTIVE and on an ARCHIVED list. The flags come from the persona fixtures (which follow
//  Docs/privacy-matrix.md and the ListFixtures scenarios); nothing here reads a role. The flag
//  canPurchase does not depend on the list status (decision L16), so both lists agree.
//
//   - non-blind owner, non-blind co-owner, ACTIVE MEMBER-role member: entry shown, quantities known.
//   - blind owner, blind co-owner, VIEWER-role member, PUBLIC non-member: nothing shown, and every
//     model action is a no-op that never reaches the service.
//
//  Fails today because RecordPurchaseModel and RecordPurchaseItemSummary do not exist yet.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("Record purchase visibility Tests", .timeLimit(.minutes(1)))
@MainActor
struct RecordPurchaseVisibilityTests {

    struct Scenario: Sendable, CustomTestStringConvertible {
        let persona: ItemFixtures.Persona
        let archived: Bool
        let allowed: Bool

        var testDescription: String { "\(persona) archived=\(archived)" }
        var capabilities: ListCapabilities { archived ? persona.archivedCapabilities : persona.capabilities }
    }

    private static let table: [(persona: ItemFixtures.Persona, allowed: Bool)] = [
        (.owner, true), (.coOwner, true), (.member, true),
        (.blindOwner, false), (.blindCoOwner, false), (.viewer, false), (.publicNonMember, false)
    ]

    static let scenarios: [Scenario] = table.flatMap { row in
        [false, true].map { Scenario(persona: row.persona, archived: $0, allowed: row.allowed) }
    }

    /// An item as a gift-activity viewer would receive it (and, defensively, as it might slip through).
    private var richItem: ListItem {
        ItemFixtures.item(
            id: "item-1", name: "Fake Lamp", price: ItemFixtures.decimal("19.99"), quantity: 4,
            status: .partial,
            purchases: [ItemFixtures.purchase(id: "p-1", quantity: 2)],
            totalQuantityPurchased: 2, quantityPurchased: 2, quantityRemaining: 2
        )
    }

    private func makeDetail(_ scenario: Scenario) -> ItemDetailState {
        ItemDetailState(
            item: richItem, context: ItemListContext(capabilities: scenario.capabilities),
            currentUserId: ItemFixtures.currentUserId, now: ItemFixtures.nowDate
        )
    }

    @Test("The flag table matches the expectation (guards the fixtures)", arguments: scenarios)
    func flagTable(scenario: Scenario) {
        #expect(scenario.capabilities.canPurchase == scenario.allowed, "\(scenario.testDescription)")
    }

    @Test("The item detail shows the purchase entry exactly when the flag allows, with quantities only then",
          arguments: scenarios)
    func detailState(scenario: Scenario) {
        let detail = makeDetail(scenario)
        #expect(detail.showsPurchaseEntry == scenario.allowed)
        if scenario.allowed {
            #expect(detail.remainingQuantity == 2)
            #expect(detail.statusMarker == .partial)
            #expect(detail.progress == 0.5)
            #expect(detail.purchases.map(\.id) == ["p-1"])
        } else {
            #expect(detail.remainingQuantity == nil)
            #expect(detail.statusMarker == nil)
            #expect(detail.progress == nil)
            #expect(detail.purchases.isEmpty)
        }
    }

    @Test("The model is allowed exactly when the flag allows; summary and Record button follow",
          arguments: scenarios)
    func modelState(scenario: Scenario) async {
        let sut = await makeRecordPurchaseModelSUT(item: richItem, capabilities: scenario.capabilities)

        #expect(sut.model.isAllowed == scenario.allowed)
        #expect((sut.model.summary != nil) == scenario.allowed)
        #expect(sut.model.showsRecordButton == scenario.allowed)
        if scenario.allowed {
            #expect(sut.model.summary?.remainingText == "2 remaining")
        } else {
            #expect(sut.model.summary == nil)
            #expect(sut.model.canTapRecord == false)
            #expect(sut.model.panel == nil)
            #expect(sut.model.errorBanner == nil)
            #expect(sut.model.showsExpired == false)
            #expect(sut.model.expiryDelay == nil)
        }
    }

    @Test("Every action is a no-op that never reaches the service when the flag does not allow",
          arguments: scenarios.filter { !$0.allowed })
    func actionsAreNoOps(scenario: Scenario) async {
        let sut = await makeRecordPurchaseModelSUT(item: richItem, capabilities: scenario.capabilities)
        sut.repo.enqueue(created: PurchaseFixtures.recordedPurchase())
        sut.repo.enqueue(.success(PurchaseServiceFix.confirmation()))
        sut.fill()
        let before = sut.model.flow.state

        await sut.model.recordTapped()
        await sut.model.confirmOverPurchase()
        await sut.model.confirmBudget()
        await sut.model.retry()
        sut.model.editDetails()
        sut.model.dismissError()
        sut.model.expiryReached()
        sut.model.cancel()

        #expect(sut.repo.callCount == 0)
        #expect(sut.model.finish == nil)
        #expect(sut.model.flow.state == before)
        #expect(sut.model.flow.state == .editing)
        #expect(sut.model.isSubmitting == false)
        #expect(sut.model.isShowingOverPurchasePrompt == false)
        #expect(sut.service.isMutating == false)
    }

    @Test("Allowed personas can record: the call reaches the service on an active and an archived list",
          arguments: scenarios.filter(\.allowed))
    func allowedCanRecord(scenario: Scenario) async {
        let sut = await makeRecordPurchaseModelSUT(item: richItem, capabilities: scenario.capabilities)
        sut.repo.enqueue(created: PurchaseFixtures.recordedPurchase())
        sut.fill()

        #expect(sut.model.canTapRecord == true)
        await sut.model.recordTapped()

        #expect(sut.repo.callCount == 1)
        #expect(sut.model.finish == .recorded(PurchaseFixtures.recordedPurchase()))
    }

    @Test("A blind persona gets no summary text from an item that carries quantities")
    func blindSummaryIsNil() async {
        let sut = await makeRecordPurchaseModelSUT(
            item: richItem, capabilities: ItemFixtures.Persona.blindOwner.capabilities
        )
        #expect(sut.model.summary == nil)
    }
}
