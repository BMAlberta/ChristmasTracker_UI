//
//  AppButtonStyles.swift
//  ChristmasTracker
//
//  The primary button style: a capsule on the primary fill with a contrast-tested label
//  (PrimaryButtonLabelTable, see AppButtonSpec.swift). Secondary actions use `.bordered` and inherit
//  the app tint; destructive actions use `.bordered` with `destructiveTint()` and the destructive role.
//

import SwiftUI

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let labelColor = Color(label: PrimaryButtonLabelTable.label(mode: colorScheme.themeMode))
        configuration.label
            .font(.appHeadline)
            .foregroundStyle(labelColor)
            // A ProgressView inside the label takes the label color, not the app tint.
            .tint(labelColor)
            .padding(.horizontal, AppSpacing.lg)
            .frame(minHeight: PrimaryButtonLabelTable.minimumHeight)
            .background(Color.primaryColor, in: Capsule())
            .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.5)
            .contentShape(Capsule())
    }
}

#Preview("Primary - light") {
    Button("Save") {}
        .buttonStyle(PrimaryButtonStyle())
        .padding(AppSpacing.lg)
        .preferredColorScheme(.light)
}

#Preview("Primary - dark") {
    Button("Save") {}
        .buttonStyle(PrimaryButtonStyle())
        .padding(AppSpacing.lg)
        .preferredColorScheme(.dark)
}

#Preview("Primary - disabled") {
    Button("Save") {}
        .buttonStyle(PrimaryButtonStyle())
        .disabled(true)
        .padding(AppSpacing.lg)
}
