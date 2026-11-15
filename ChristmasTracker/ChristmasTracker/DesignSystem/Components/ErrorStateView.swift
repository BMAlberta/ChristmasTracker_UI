//
//  ErrorStateView.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/12/26.
//
import SwiftUI

/// Reusable error state component with retry action
struct ErrorStateView: View {
    
    let error: Error
    let onRetry: () -> Void

    /// Decorative icon size: 64pt at the default text size, scaling with Dynamic Type.
    @ScaledMetric(relativeTo: .largeTitle) private var heroSize: CGFloat = 64

    var body: some View {
        VStack(spacing: AppSpacing.xl) {
            // Error icon
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: heroSize))
                .foregroundColor(.red)
            
            // Error message
            VStack(spacing: AppSpacing.sm) {
                Text("Something Went Wrong")
                    .font(.appTitle2)
                    .foregroundColor(.textPrimaryColor)
                
                Text(error.localizedDescription)
                    .font(.appBody)
                    .foregroundColor(.textMutedColor)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.xl)
            }
            
            // Retry button
            Button(action: onRetry) {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "arrow.clockwise")
                    Text("Try Again")
                }
            }
            .font(.appHeadline)
            .foregroundColor(.white)
            .padding(.horizontal, AppSpacing.xl)
            .padding(.vertical, AppSpacing.md)
            .background(Color.primaryColor)
            .cornerRadius(12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.backgroundPrimaryColor)
    }
}

#Preview("Network Error") {
    ErrorStateView(
        error: URLError(.notConnectedToInternet)
    ) {
        print("Retry tapped")
    }
}

#Preview("Generic Error") {
    ErrorStateView(
        error: NSError(
            domain: "com.christmastracker",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Failed to load data. Please check your connection and try again."]
        )
    ) {
        print("Retry tapped")
    }
}
