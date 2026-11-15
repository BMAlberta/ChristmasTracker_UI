// UpdateGateTests.swift
// ChristmasTrackerTests
//
// Pure decision table for UpdateGate (VER1 decisions 1, 5, 8).

import Testing
import Foundation
import TrackerAPI
@testable import ChristmasTracker

@Suite("UpdateGate")
@MainActor
struct UpdateGateTests {

    private typealias F = VersionTestFixtures

    private func decide(
        policy: VersionPolicy? = nil,
        policyOrder: Int = 0,
        outdated: VersionOutdatedDetails? = nil,
        outdatedOrder: Int = 0,
        dismissed: String? = nil
    ) -> UpdateGate.Decision {
        UpdateGate.decide(
            policy: policy,
            policyOrder: policyOrder,
            outdated: outdated,
            outdatedOrder: outdatedOrder,
            dismissedLatestVersion: dismissed
        )
    }

    private func isNone(_ d: UpdateGate.Decision) -> Bool {
        if case .none = d { return true }
        return false
    }

    private func recommended(_ d: UpdateGate.Decision) -> VersionPolicy? {
        if case .recommended(let p) = d { return p }
        return nil
    }

    private func required(_ d: UpdateGate.Decision) -> RequiredUpdate? {
        if case .required(let r) = d { return r }
        return nil
    }

    // MARK: policy only

    @Test("no sources gives none")
    func noSources() {
        #expect(isNone(decide()))
    }

    @Test("ok policy gives none")
    func okIsNone() {
        #expect(isNone(decide(policy: F.policy(state: .ok), policyOrder: 1)))
    }

    @Test("updateRecommended gives recommended with that policy")
    func recommendedPolicy() {
        let p = F.policy(state: .updateRecommended)
        #expect(recommended(decide(policy: p, policyOrder: 1)) == p)
    }

    @Test("forceUpdate gives required carrying the policy data")
    func forceUpdatePolicy() {
        let p = F.policy(state: .forceUpdate, minimumVersion: "1.5.0", minimumBuild: 42,
                         manifestURL: URL(string: "https://example.com/m.plist"), releaseNotes: "Notes")
        let r = required(decide(policy: p, policyOrder: 1))
        #expect(r == RequiredUpdate(minimumVersion: "1.5.0", minimumBuild: 42,
                                    manifest: "https://example.com/m.plist", releaseNotes: "Notes"))
    }

    // MARK: 426 only

    @Test("426 with details gives required without release notes")
    func outdatedWithDetails() {
        let r = required(decide(outdated: F.outdated(minimumVersion: "3.0.0", minimumBuild: 99,
                                                    manifestUrl: "https://example.com/m.plist"),
                                outdatedOrder: 1))
        #expect(r == RequiredUpdate(minimumVersion: "3.0.0", minimumBuild: 99,
                                    manifest: "https://example.com/m.plist", releaseNotes: nil))
    }

    @Test("426 without usable details (empty minimumVersion, nil manifest) still blocks")
    func outdatedWithoutDetails() {
        let r = required(decide(outdated: F.outdated(minimumVersion: "", minimumBuild: nil, manifestUrl: nil),
                                outdatedOrder: 1))
        #expect(r != nil)
        #expect(r?.manifest == nil)
        #expect(r?.releaseNotes == nil)
        #expect(r?.minimumVersion == "")
    }

    @Test("426 with nil manifest but a minimum version still blocks with no link")
    func outdatedNilManifest() {
        let r = required(decide(outdated: F.outdated(manifestUrl: nil), outdatedOrder: 1))
        #expect(r?.minimumVersion == "3.0.0")
        #expect(r?.manifest == nil)
    }

    // MARK: both sources

    @Test("both sources with the 426 newer gives required from the 426")
    func outdatedNewerThanRecommended() {
        let r = required(decide(policy: F.policy(state: .updateRecommended), policyOrder: 1,
                                outdated: F.outdated(minimumVersion: "3.0.0"), outdatedOrder: 2))
        #expect(r?.minimumVersion == "3.0.0")
    }

    @Test("policy forceUpdate with an older 426 gives required")
    func forceUpdateOverOlderOutdated() {
        let r = required(decide(policy: F.policy(state: .forceUpdate, minimumVersion: "1.5.0"), policyOrder: 2,
                                outdated: F.outdated(), outdatedOrder: 1))
        #expect(r == RequiredUpdate(minimumVersion: "1.5.0", minimumBuild: 20,
                                    manifest: "https://example.com/app/manifest.plist",
                                    releaseNotes: "Fixes and polish"))
        #expect(r?.releaseNotes != nil)
    }

    @Test("a present policy and a 426 both at order 0 block, the tie going to the 426")
    func zeroOrderTieBlocks() {
        let d = decide(policy: F.policy(state: .ok), policyOrder: 0,
                       outdated: F.outdated(minimumVersion: "3.0.0"), outdatedOrder: 0)
        #expect(required(d)?.minimumVersion == "3.0.0")
    }

    @Test("a newer ok policy clears an older 426")
    func okPolicyClearsOlderOutdated() {
        #expect(isNone(decide(policy: F.policy(state: .ok), policyOrder: 2,
                              outdated: F.outdated(), outdatedOrder: 1)))
    }

    @Test("a newer ok policy clears an older policy forceUpdate (the policy is replaced)")
    func okPolicyClearsForceUpdate() {
        // The service replaces lastPolicy, so only the newest policy is ever passed in.
        #expect(isNone(decide(policy: F.policy(state: .ok), policyOrder: 3)))
    }

    @Test("a 426 newer than an ok policy blocks again")
    func outdatedAfterOkBlocks() {
        #expect(required(decide(policy: F.policy(state: .ok), policyOrder: 1,
                                outdated: F.outdated(), outdatedOrder: 2)) != nil)
    }

    @Test("a 426 with the same order as the policy still blocks")
    func outdatedSameAgeWins() {
        #expect(required(decide(policy: F.policy(state: .ok), policyOrder: 2,
                                outdated: F.outdated(), outdatedOrder: 2)) != nil)
    }

    @Test("a newer recommended policy supersedes an older 426")
    func recommendedSupersedesOlderOutdated() {
        let p = F.policy(state: .updateRecommended)
        let d = decide(policy: p, policyOrder: 2, outdated: F.outdated(), outdatedOrder: 1)
        #expect(recommended(d) == p)
    }

    // MARK: dismissal

    @Test("dismissed latestVersion hides recommended for that string")
    func dismissalHidesRecommended() {
        let p = F.policy(state: .updateRecommended, latestVersion: "2.0.0")
        #expect(isNone(decide(policy: p, policyOrder: 1, dismissed: "2.0.0")))
    }

    @Test("a different dismissed latestVersion does not hide recommended")
    func differentDismissalShows() {
        let p = F.policy(state: .updateRecommended, latestVersion: "2.1.0")
        #expect(recommended(decide(policy: p, policyOrder: 1, dismissed: "2.0.0")) == p)
    }

    @Test("dismissal never hides a policy forceUpdate")
    func dismissalDoesNotHideForceUpdate() {
        let p = F.policy(state: .forceUpdate, latestVersion: "2.0.0")
        #expect(required(decide(policy: p, policyOrder: 1, dismissed: "2.0.0")) != nil)
    }

    @Test("dismissal never hides a 426")
    func dismissalDoesNotHideOutdated() {
        #expect(required(decide(outdated: F.outdated(), outdatedOrder: 1, dismissed: "2.0.0")) != nil)
    }
}
