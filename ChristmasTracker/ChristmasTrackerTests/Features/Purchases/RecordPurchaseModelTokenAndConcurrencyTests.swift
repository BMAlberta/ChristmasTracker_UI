//
//  RecordPurchaseModelTokenAndConcurrencyTests.swift
//  ChristmasTrackerTests
//
//  Story I4a-C (e): a second action while a request is in flight does not start a second call, and
//  the confirmation token is never exposed by the model: no token property, no token in a Mirror
//  walk of the model, no token in String(describing:) or String(reflecting:) of the flow or in the
//  panel, the error banner or the summary. The token lives only inside the flow's pending
//  confirmation and in the local value handed to the one service call.
//
//  Fails today because RecordPurchaseModel does not exist yet.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("Record purchase model token and concurrency Tests", .timeLimit(.minutes(1)))
@MainActor
struct RecordPurchaseModelTokenAndConcurrencyTests {

    private let token = RecordPurchaseTestToken.first

    private func makeSUT() async -> RecordPurchaseModelSUT {
        await makeRecordPurchaseModelSUT(item: ItemFixtures.item(id: "item-1", quantity: 3, quantityRemaining: 3))
    }

    // MARK: Double tap

    @Test("A second Record tap while the first request is in flight starts no second call")
    func doubleTapRecord() async {
        let sut = await makeSUT()
        sut.fill()
        sut.repo.enqueue(created: PurchaseFixtures.recordedPurchase(), held: true)
        let first = Task { @MainActor in await sut.model.recordTapped() }
        await sut.repo.gate.nextHeldCall()
        #expect(sut.model.isSubmitting == true)
        #expect(sut.model.canTapRecord == false)

        await sut.model.recordTapped()
        await sut.model.confirmOverPurchase()
        await sut.model.confirmBudget()
        await sut.model.retry()

        #expect(sut.repo.callCount == 1)
        sut.repo.gate.releaseAll()
        await first.value
        #expect(sut.repo.callCount == 1)
        #expect(sut.model.finish == .recorded(PurchaseFixtures.recordedPurchase()))
    }

    @Test("A second Record Anyway tap while the confirmed request is in flight starts no second call")
    func doubleTapConfirm() async {
        let sut = await makeSUT()
        await sut.driveToAwaiting(token: token)
        sut.repo.enqueue(created: PurchaseFixtures.recordedPurchase(), held: true)
        let first = Task { @MainActor in await sut.model.confirmBudget() }
        await sut.repo.gate.nextHeldCall()

        await sut.model.confirmBudget()

        #expect(sut.repo.callCount == 2)
        #expect(sut.repo.calls.filter { $0.token == token }.count == 1)
        sut.repo.gate.releaseAll()
        await first.value
        #expect(sut.repo.callCount == 2)
    }

    @Test("Edit Details, Cancel and expiry are ignored while the confirmed request is in flight")
    func otherActionsIgnoredInFlight() async {
        let sut = await makeSUT()
        await sut.driveToAwaiting(token: token)
        sut.repo.enqueue(created: PurchaseFixtures.recordedPurchase(), held: true)
        let first = Task { @MainActor in await sut.model.confirmBudget() }
        await sut.repo.gate.nextHeldCall()

        sut.model.editDetails()
        sut.model.cancel()
        sut.clock.advance(by: 1_000)
        sut.model.expiryReached()

        #expect(sut.model.finish == nil)
        #expect(sut.model.isSubmitting == true)
        #expect(sut.model.fieldsAreReadOnly == true)
        sut.repo.gate.releaseAll()
        await first.value
        #expect(sut.model.finish == .recorded(PurchaseFixtures.recordedPurchase()))
    }

    // MARK: Token exposure

    /// Every string reachable by walking the value with Mirror (labels, values, children).
    private func reflectedStrings(_ value: Any, depth: Int = 0) -> [String] {
        guard depth < 8 else { return [] }
        var found: [String] = []
        if let text = value as? String { found.append(text) }
        for child in Mirror(reflecting: value).children {
            if let label = child.label { found.append(label) }
            found += reflectedStrings(child.value, depth: depth + 1)
        }
        return found
    }

    @Test("The model has no token-named member")
    func noTokenMember() async {
        let sut = await makeSUT()
        await sut.driveToAwaiting(token: token)

        let labels = Mirror(reflecting: sut.model).children.compactMap { $0.label }
        for label in labels {
            #expect(!label.lowercased().contains("token"), "\(label)")
        }
    }

    @Test("While awaiting confirmation no rendering of the model, the flow, the panel or the summary has the token")
    func noTokenInRenderings() async {
        let sut = await makeSUT()
        await sut.driveToAwaiting(token: token)
        #expect(sut.model.panel != nil, "precondition: awaiting confirmation")

        let subjects: [(String, Any)] = [
            ("model", sut.model),
            ("flow", sut.model.flow),
            ("flow state", sut.model.flow.state),
            ("panel", sut.model.panel as Any),
            ("summary", sut.model.summary as Any),
            ("input", sut.model.input),
            ("formState", sut.model.formState)
        ]
        for (name, value) in subjects {
            #expect(!String(describing: value).contains(token), "describing \(name)")
            #expect(!String(reflecting: value).contains(token), "reflecting \(name)")
            #expect(!"\(value)".contains(token), "interpolating \(name)")
            var dumped = ""
            dump(value, to: &dumped)
            #expect(!dumped.contains(token), "dump \(name)")
            #expect(!reflectedStrings(value).contains { $0.contains(token) }, "mirror \(name)")
        }
    }

    @Test("The redacted flow description is the placeholder and nothing secret")
    func flowDescriptionIsRedacted() async {
        let sut = await makeSUT()
        await sut.driveToAwaiting(token: token)

        #expect(String(describing: sut.model.flow).contains("<redacted token>"))
        #expect(String(describing: sut.model.flow.state).contains("<redacted token>"))
    }

    @Test("The token is gone from the flow after success, failure, cancel, edit and expiry", arguments: [
        "success", "failure", "cancel", "edit", "expiry"
    ])
    func tokenGoneAfterLeaving(exit: String) async {
        let sut = await makeSUT()
        await sut.driveToAwaiting(token: token)

        switch exit {
        case "success":
            sut.repo.enqueue(created: PurchaseFixtures.recordedPurchase())
            await sut.model.confirmBudget()
        case "failure":
            sut.repo.enqueueFailure(PurchaseError.server)
            await sut.model.confirmBudget()
        case "cancel":
            sut.model.cancel()
        case "edit":
            sut.model.editDetails()
        default:
            sut.clock.advance(by: 270)
            sut.model.expiryReached()
        }

        #expect(!String(describing: sut.model.flow).contains(token), Comment(rawValue: exit))
        #expect(!String(reflecting: sut.model.flow).contains(token), Comment(rawValue: exit))
        #expect(!reflectedStrings(sut.model).contains { $0.contains(token) }, Comment(rawValue: exit))
        #expect(sut.model.panel == nil, Comment(rawValue: exit))
    }

    @Test("The error banner, the summary and the panel text never contain the token")
    func noTokenInVisibleText() async {
        let sut = await makeSUT()
        await sut.driveToAwaiting(token: token)
        var texts: [String] = []
        if let panel = sut.model.panel {
            texts += panel.rows.flatMap { [$0.label, $0.budgetLimitText, $0.alreadySpentText, $0.thisPurchaseText, $0.overByText] }
            texts += [panel.cancelTitle, panel.confirmTitle, panel.editTitle, panel.announcement]
            texts += panel.noticeText.map { [$0] } ?? []
        }
        if let summary = sut.model.summary {
            texts += [summary.name, summary.requestedText] + [summary.remainingText, summary.expectedPriceText].compactMap { $0 }
        }
        #expect(!texts.isEmpty)
        for text in texts {
            #expect(!text.contains(token), "\(text)")
        }
    }
}
