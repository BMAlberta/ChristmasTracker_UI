//
//  RecordPurchaseFlowIgnoredEventsTests.swift
//  ChristmasTrackerTests
//
//  Story I4a-A: "an event not listed for a state is ignored: state unchanged, no effect". The
//  matrix is PurchaseFlowStage x PurchaseFlowStage.ignoredEvents (every event the transition
//  table does not list for that stage). In particular cancel is ignored while a request is in
//  flight, and recorded is terminal.
//
//  Fails today because RecordPurchaseFlow and its types do not exist yet.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("Record purchase flow ignored events Tests")
struct RecordPurchaseFlowIgnoredEventsTests {

    @Test("Events the table does not list for a state change nothing and produce no effect",
          arguments: PurchaseFlowStage.allCases)
    func ignoredEventsAreNoOps(stage: PurchaseFlowStage) {
        for event in stage.ignoredEvents {
            var sut = stage.makeHarness()
            let before = sut.state
            let effect = sut.send(event)
            #expect(sut.state == before, "\(stage) + \(event)")
            #expect(effect == nil, "\(stage) + \(event)")
        }
    }

    @Test("cancel is ignored while a request is in flight, confirmed or not",
          arguments: [PurchaseFlowStage.submitting, .confirmedSubmitting])
    func cancelIgnoredWhileSubmitting(stage: PurchaseFlowStage) {
        var sut = stage.makeHarness()
        let before = sut.state
        #expect(sut.send(.cancel) == nil)
        #expect(sut.state == before)
    }

    @Test("A late server answer after the flow was recorded does not change the recorded purchase")
    func lateAnswerAfterRecorded() {
        var sut = PurchaseFlowHarness()
        let purchase = PurchaseFixtures.recordedPurchase(id: "purchase-first")
        sut.driveToRecorded(purchase)
        sut.send(.serverCreated(PurchaseFixtures.recordedPurchase(id: "purchase-late")))
        sut.send(.serverError(.network))
        #expect(sut.state == .recorded(purchase))
    }

    @Test("A late server answer after the user returned to editing is ignored")
    func lateAnswerAfterEditing() {
        var sut = PurchaseFlowHarness()
        sut.driveToAwaiting()
        sut.send(.editDetails)
        sut.send(.serverConfirmationRequired(warnings: [PurchaseFixtures.totalWarning()], token: "tok-LATE"))
        #expect(sut.state == .editing)
        #expect(String(describing: sut.state).contains("tok-LATE") == false)
    }
}
