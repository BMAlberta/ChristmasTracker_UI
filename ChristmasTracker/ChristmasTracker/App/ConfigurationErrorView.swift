//
//  ConfigurationErrorView.swift
//  ChristmasTracker
//
//  The only screen shown when real mode has no generated client. Plain text, no buttons, no sign-in.
//

import SwiftUI

struct ConfigurationErrorView: View {
    let state: ConfigurationErrorState

    var body: some View {
        Text(ConfigurationErrorState.message)
            .font(.appBody)
            .foregroundStyle(Color.textPrimaryColor)
            .multilineTextAlignment(.center)
            .padding(AppSpacing.xl)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.backgroundPrimaryColor)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(state.accessibilityLabel)
            .accessibilityIdentifier("configurationError.message")
    }
}

#Preview {
    if let state = ConfigurationErrorState.state(for: .failed) {
        ConfigurationErrorView(state: state)
    }
}
