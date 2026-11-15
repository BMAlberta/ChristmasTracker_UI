//
//  ForgotPasswordView.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/11/26.
//

import SwiftUI
struct ForgotPasswordView: View {
    @Environment(\.dismiss) private var dismiss

    /// Decorative icon size: 64pt at the default text size, scaling with Dynamic Type.
    @ScaledMetric(relativeTo: .largeTitle) private var heroSize: CGFloat = 64

    var body: some View {
        NavigationStack {
            VStack(spacing: AppSpacing.xl) {
                Image(systemName: "envelope.badge.shield.half.filled")
                    .font(.system(size: heroSize))
                    .foregroundStyle(Color.primaryColor)
                Text("Forgot Password?")
                    .font(.appTitle2)
                    .foregroundStyle(Color.textPrimaryColor)
                Text("Password resets are handled by your administrator. Contact them directly for assistance.")
                    .font(.appBody)
                    .foregroundStyle(Color.textMutedColor)
                    .multilineTextAlignment(.center)
                Spacer()
            }
            .padding(EdgeInsets.appScreenPadding)
            .background(Color.backgroundPrimaryColor)
            .navigationTitle("Forgot Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}
#Preview {
    ForgotPasswordView()
}
