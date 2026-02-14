//
//  LoadingView.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/13/26.
//

import SwiftUI

import SwiftUI

/// Simple loading indicator with optional message
struct LoadingView: View {
    
    var message: String = "Loading..."
    
    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            ProgressView()
                .tint(.primaryColor)
                .scaleEffect(1.2)
            
            Text(message)
                .font(.appBody)
                .foregroundColor(.textMutedColor)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.backgroundPrimaryColor)
    }
}

#Preview("Default") {
    LoadingView()
}

#Preview("Custom Message") {
    LoadingView(message: "Loading list details...")
}

#Preview("In Card") {
    LoadingView(message: "Please wait...")
        .frame(height: 200)
        .background(Color.surfaceColor)
        .cornerRadius(12)
        .padding()
}
