// UpdatePromptModifier.swift
// ChristmasTracker
//
// Applies the update decision at the app root: a required update covers everything with a
// full-screen view (not a sheet, no dismiss), a recommended one shows a native alert.
// The cover does not touch authentication state.

import SwiftUI

extension View {
    /// Covers the content when an update is required; asks once when one is recommended.
    func updatePrompt(
        service: VersionService,
        gate: VersionGate,
        installedVersion: String,
        installedBuild: String
    ) -> some View {
        modifier(UpdatePromptModifier(
            service: service, gate: gate, installedVersion: installedVersion, installedBuild: installedBuild))
    }
}

private struct UpdatePromptModifier: ViewModifier {
    let service: VersionService
    let gate: VersionGate
    let installedVersion: String
    let installedBuild: String

    @Environment(\.openURL) private var openURL
    @State private var isChecking = false

    private var decision: UpdateGate.Decision {
        UpdateGate.decide(
            policy: service.lastPolicy,
            policyOrder: service.policyOrder,
            outdated: gate.latestDetails,
            outdatedOrder: gate.outdatedOrder,
            dismissedLatestVersion: service.dismissedLatestVersion
        )
    }

    func body(content: Content) -> some View {
        let current = decision
        let covered = UpdatePresentation.hidesContent(for: current)
        return ZStack {
            content
                .accessibilityHidden(covered)
                .allowsHitTesting(!covered)
            if case .required(let update) = current {
                UpdateRequiredView(
                    update: update,
                    installedVersion: installedVersion,
                    installedBuild: installedBuild,
                    isChecking: isChecking,
                    onCheckAgain: checkAgain
                )
                .transition(.identity)
            }
        }
        .alert(
            UpdatePresentation.promptTitle,
            isPresented: Binding(get: { UpdatePresentation.showsPrompt(for: current) }, set: { _ in }),
            presenting: recommendedPolicy(current)
        ) { policy in
            Button("Update") { update(policy, decision: current) }
            Button("Later", role: .cancel) { service.dismissRecommended(latestVersion: policy.latestVersion) }
        } message: { policy in
            Text(UpdatePresentation.promptMessage(
                latestVersion: policy.latestVersion, releaseNotes: policy.releaseNotes))
        }
    }

    private func recommendedPolicy(_ decision: UpdateGate.Decision) -> VersionPolicy? {
        guard case .recommended(let policy) = decision else { return nil }
        return policy
    }

    /// Opens the install link, and also dismisses for this latestVersion: the alert is derived
    /// from state, so without the dismissal it would present again immediately.
    private func update(_ policy: VersionPolicy, decision: UpdateGate.Decision) {
        if let link = UpdatePresentation.installLink(for: decision) {
            openURL(link)
        }
        service.dismissRecommended(latestVersion: policy.latestVersion)
    }

    private func checkAgain() async {
        isChecking = true
        await service.check()
        isChecking = false
    }
}
