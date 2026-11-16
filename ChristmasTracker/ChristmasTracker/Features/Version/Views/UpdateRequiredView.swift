// UpdateRequiredView.swift
// ChristmasTracker
//
// Full-screen, value-driven "Update required" screen. It has no dismiss control and touches
// no session state; it only opens the install link and asks for another check.

import SwiftUI

struct UpdateRequiredView: View {
    let update: RequiredUpdate
    let installedVersion: String
    let installedBuild: String
    let isChecking: Bool
    let onCheckAgain: () async -> Void

    @Environment(\.openURL) private var openURL

    private var installLink: URL? {
        UpdatePresentation.installLink(for: .required(update))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                Text(UpdatePresentation.appName)
                    .font(.appBrand)
                    .foregroundStyle(Color.primaryColor)
                    .accessibilityHidden(true)
                header
                details
                actions
            }
            .frame(maxWidth: .infinity)
            .padding(AppSpacing.xl)
        }
        .background(Color.backgroundPrimaryColor.ignoresSafeArea())
    }

    private var header: some View {
        Text(UpdatePresentation.requiredTitle)
            .font(.appTitle2)
            .foregroundStyle(Color.textPrimaryColor)
            .multilineTextAlignment(.center)
            .accessibilityAddTraits(.isHeader)
            .accessibilitySortPriority(1)
    }

    private var details: some View {
        VStack(spacing: AppSpacing.md) {
            Text(UpdatePresentation.requiredSentence)
                .font(.appBody)
                .foregroundStyle(Color.textPrimaryColor)
            Text(UpdatePresentation.versionLine(
                installedVersion: installedVersion, installedBuild: installedBuild, required: update))
                .font(.appFootnote)
                .foregroundStyle(Color.textMutedColor)
            if let notes = UpdatePresentation.requiredNotes(update.releaseNotes) {
                Text(verbatim: notes)
                    .font(.appCallout)
                    .foregroundStyle(Color.textPrimaryColor)
            }
        }
        .multilineTextAlignment(.center)
    }

    @ViewBuilder
    private var actions: some View {
        if let link = installLink {
            Button("Update") { openURL(link) }
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityLabel("Update Christmas Tracker")
        } else {
            Text(UpdatePresentation.noLinkMessage)
                .font(.appCallout)
                .foregroundStyle(Color.textMutedColor)
                .multilineTextAlignment(.center)
        }
        checkAgainButton
    }

    private var checkAgainButton: some View {
        Button {
            Task { await onCheckAgain() }
        } label: {
            HStack(spacing: AppSpacing.sm) {
                if isChecking { ProgressView() }
                Text("Check again")
            }
            .font(.appSubheadline)
            .foregroundStyle(Color.primaryColor)
            .padding(AppSpacing.sm)
        }
        .buttonStyle(.plain)
        .disabled(isChecking)
    }
}

// MARK: - Previews

private enum UpdateRequiredPreviewData {
    static let manifest = MockVersionState.required.policy.manifestURL?.absoluteString

    static func update(manifest: String?, notes: String?) -> RequiredUpdate {
        RequiredUpdate(minimumVersion: "2.0.0", minimumBuild: 200, manifest: manifest, releaseNotes: notes)
    }

    static func screen(_ update: RequiredUpdate) -> some View {
        UpdateRequiredView(
            update: update, installedVersion: "1.4", installedBuild: "120", isChecking: false, onCheckAgain: {})
    }
}

#Preview("Required with notes") {
    UpdateRequiredPreviewData.screen(
        UpdateRequiredPreviewData.update(
            manifest: UpdateRequiredPreviewData.manifest, notes: "Fixes a sign-in problem."
        ))
}

#Preview("Required without notes, dark") {
    UpdateRequiredPreviewData.screen(
        UpdateRequiredPreviewData.update(manifest: UpdateRequiredPreviewData.manifest, notes: nil))
        .preferredColorScheme(.dark)
}

#Preview("Required without a link") {
    UpdateRequiredPreviewData.screen(UpdateRequiredPreviewData.update(manifest: nil, notes: nil))
}

#Preview("Largest accessibility size") {
    UpdateRequiredPreviewData.screen(
        UpdateRequiredPreviewData.update(
            manifest: UpdateRequiredPreviewData.manifest, notes: "Fixes a sign-in problem."
        ))
        .dynamicTypeSize(.accessibility5)
}
