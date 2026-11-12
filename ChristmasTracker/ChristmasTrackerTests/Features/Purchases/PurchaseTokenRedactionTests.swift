//
//  PurchaseTokenRedactionTests.swift
//  ChristmasTrackerTests
//
//  Story I4a-B (decision 3): every type that stores a confirmation token prints the placeholder
//  `<redacted token>` in place of the token and nothing else secret. That covers
//  PendingConfirmation, RecordPurchaseFlowState (awaitingConfirmation), RecordPurchaseFlowEvent
//  (serverConfirmationRequired), RecordPurchaseFlowEffect (send), RecordPurchaseFlow and
//  PurchaseOutcome (confirmationRequired).
//
//  `String(describing:)`, `String(reflecting:)`, `dump`, string interpolation and containers of the
//  value never contain the token string; the placeholder is present in the description forms;
//  Equatable still compares the real tokens.
//
//  The token is the distinctive fake "tok-fixture-ABC123".
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("Purchase token redaction", .timeLimit(.minutes(1)))
struct PurchaseTokenRedactionTests {

    private static let token = PurchaseWire.token
    private static let placeholder = "<redacted token>"

    /// Every value that stores the token, named for the failure message.
    private struct Subject {
        let name: String
        let value: Any
    }

    private func subjects() -> [Subject] {
        let warnings = [PurchaseFixtures.recipientWarning(), PurchaseFixtures.totalWarning()]
        let pending = PendingConfirmation(
            warnings: warnings, token: Self.token, issuedAt: PurchaseTestClock.start, notice: nil
        )
        var harness = PurchaseFlowHarness()
        harness.driveToAwaiting(warnings: warnings, token: Self.token)
        return [
            Subject(name: "PendingConfirmation", value: pending),
            Subject(name: "flow state awaitingConfirmation", value: RecordPurchaseFlowState.awaitingConfirmation(pending)),
            Subject(name: "flow state from the flow", value: harness.state),
            Subject(name: "RecordPurchaseFlow", value: harness.flow),
            Subject(name: "confirmationRequired outcome",
                    value: PurchaseOutcome.confirmationRequired(warnings: warnings, token: Self.token)),
            Subject(name: "send effect", value: RecordPurchaseFlowEffect.send(confirmationToken: Self.token)),
            Subject(name: "serverConfirmationRequired event",
                    value: RecordPurchaseFlowEvent.serverConfirmationRequired(warnings: warnings, token: Self.token))
        ]
    }

    // MARK: No token in any rendering

    @Test("String(describing:) never contains the token")
    func describingHasNoToken() {
        for subject in subjects() {
            #expect(!String(describing: subject.value).contains(Self.token), "\(subject.name)")
        }
    }

    @Test("String(reflecting:) never contains the token")
    func reflectingHasNoToken() {
        for subject in subjects() {
            #expect(!String(reflecting: subject.value).contains(Self.token), "\(subject.name)")
        }
    }

    @Test("dump never contains the token")
    func dumpHasNoToken() {
        for subject in subjects() {
            var text = ""
            dump(subject.value, to: &text)
            #expect(!text.contains(Self.token), "\(subject.name): \(text)")
        }
    }

    @Test("string interpolation never contains the token")
    func interpolationHasNoToken() {
        for subject in subjects() {
            let text = "value: \(subject.value) end"
            #expect(!text.contains(Self.token), "\(subject.name)")
        }
    }

    @Test("a Mirror walk of the value never reaches the token string")
    func mirrorWalkHasNoToken() {
        func walk(_ value: Any, depth: Int = 0) -> [String] {
            if depth > 8 { return [] }
            var found: [String] = []
            if let text = value as? String { found.append(text) }
            for child in Mirror(reflecting: value).children {
                found.append(contentsOf: walk(child.value, depth: depth + 1))
            }
            return found
        }
        for subject in subjects() {
            let strings = walk(subject.value)
            #expect(!strings.contains(Self.token), "\(subject.name)")
        }
    }

    @Test("containers of the value do not reveal the token: array, optional, result, dictionary")
    func containersHaveNoToken() {
        for subject in subjects() {
            let array = String(describing: [subject.value])
            let optional = String(describing: Optional(subject.value))
            let result = String(describing: Result<Any, Never>.success(subject.value))
            let dictionary = String(describing: ["key": subject.value])
            for text in [array, optional, result, dictionary] {
                #expect(!text.contains(Self.token), "\(subject.name): \(text)")
            }
        }
    }

    @Test("the warnings value never contains the token")
    func warningsHaveNoToken() {
        let warnings = [PurchaseFixtures.recipientWarning(), PurchaseFixtures.totalWarning()]
        var dumped = ""
        dump(warnings, to: &dumped)

        #expect(!String(describing: warnings).contains(Self.token))
        #expect(!String(reflecting: warnings).contains(Self.token))
        #expect(!dumped.contains(Self.token))
    }

    // MARK: The placeholder is present

    @Test("the description forms print the redaction placeholder in place of the token")
    func placeholderIsPresent() {
        for subject in subjects() {
            #expect(String(describing: subject.value).contains(Self.placeholder), "describing: \(subject.name)")
            #expect(String(reflecting: subject.value).contains(Self.placeholder), "reflecting: \(subject.name)")
            #expect("\(subject.value)".contains(Self.placeholder), "interpolation: \(subject.name)")
        }
    }

    @Test("the description of a flow state without a token carries no placeholder", arguments: PurchaseFlowStage.allCases)
    func stateWithoutTokenHasNoPlaceholder(stage: PurchaseFlowStage) {
        guard stage != .awaiting else { return }
        let state = stage.makeHarness().state

        #expect(!String(describing: state).contains(Self.placeholder), "\(stage.testDescription)")
        #expect(!String(describing: state).contains("tok-"))
    }

    @Test("a send effect without a token shows no placeholder and no token")
    func sendWithoutToken() {
        let text = String(describing: RecordPurchaseFlowEffect.send(confirmationToken: nil))

        #expect(!text.contains(Self.placeholder))
        #expect(!text.contains(Self.token))
    }

    // MARK: Nothing else secret

    @Test("the flow state description still names the state, so logs stay useful")
    func descriptionNamesTheState() {
        var harness = PurchaseFlowHarness()
        harness.driveToAwaiting(token: Self.token)

        let text = String(describing: harness.state)

        #expect(text.contains("awaitingConfirmation"))
    }

    // MARK: Equatable still compares the real tokens

    @Test("Equatable still compares tokens: same token is equal, a different token is not")
    func equatableComparesTokens() {
        let warnings = [PurchaseFixtures.recipientWarning()]
        let issued = PurchaseTestClock.start
        let one = PendingConfirmation(warnings: warnings, token: Self.token, issuedAt: issued, notice: nil)
        let same = PendingConfirmation(warnings: warnings, token: Self.token, issuedAt: issued, notice: nil)
        let other = PendingConfirmation(warnings: warnings, token: PurchaseWire.secondToken, issuedAt: issued, notice: nil)

        #expect(one == same)
        #expect(one != other)
        #expect(RecordPurchaseFlowState.awaitingConfirmation(one) == .awaitingConfirmation(same))
        #expect(RecordPurchaseFlowState.awaitingConfirmation(one) != .awaitingConfirmation(other))
    }

    @Test("Equatable on outcomes, effects and events still compares tokens")
    func equatableOnOutcomeEffectEvent() {
        let warnings = [PurchaseFixtures.recipientWarning()]

        #expect(PurchaseOutcome.confirmationRequired(warnings: warnings, token: Self.token)
                == .confirmationRequired(warnings: warnings, token: Self.token))
        #expect(PurchaseOutcome.confirmationRequired(warnings: warnings, token: Self.token)
                != .confirmationRequired(warnings: warnings, token: PurchaseWire.secondToken))
        #expect(RecordPurchaseFlowEffect.send(confirmationToken: Self.token) == .send(confirmationToken: Self.token))
        #expect(RecordPurchaseFlowEffect.send(confirmationToken: Self.token) != .send(confirmationToken: PurchaseWire.secondToken))
        #expect(RecordPurchaseFlowEffect.send(confirmationToken: Self.token) != .send(confirmationToken: nil))
        #expect(RecordPurchaseFlowEvent.serverConfirmationRequired(warnings: warnings, token: Self.token)
                == .serverConfirmationRequired(warnings: warnings, token: Self.token))
        #expect(RecordPurchaseFlowEvent.serverConfirmationRequired(warnings: warnings, token: Self.token)
                != .serverConfirmationRequired(warnings: warnings, token: PurchaseWire.secondToken))
    }

    @Test("redaction does not change behavior: the confirm event still sends the real token")
    func behaviorStillUsesTheRealToken() {
        var harness = PurchaseFlowHarness()
        harness.driveToAwaiting(token: Self.token)

        let effect = harness.send(.confirm)

        #expect(effect == .send(confirmationToken: Self.token))
    }
}
