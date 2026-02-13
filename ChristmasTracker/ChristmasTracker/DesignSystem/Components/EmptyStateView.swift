//
//  EmptyStateView.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/6/26.
//

// DesignSystem/Components/EmptyStates/EmptyStateView.swift

import SwiftUI

/// Reusable empty state component
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?
    
    init(
        icon: String,
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }
    
    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 64))
                .foregroundColor(.textMutedColor)
            
            VStack(spacing: AppSpacing.sm) {
                Text(title)
                    .font(.appTitle2)
                    .foregroundColor(.textPrimaryColor)
                
                Text(message)
                    .font(.appBody)
                    .foregroundColor(.textMutedColor)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.xl)
            }
            
            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.appHeadline)
                        .foregroundColor(.white)
                        .padding(.horizontal, AppSpacing.xl)
                        .padding(.vertical, AppSpacing.md)
                        .background(Color.primaryColor)
                        .cornerRadius(12)
                }
                .padding(.top, AppSpacing.md)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.backgroundPrimaryColor)
    }
}

#Preview("Basic") {
    EmptyStateView(
        icon: "gift.fill",
        title: "No Lists Yet",
        message: "Create your first gift list to get started"
    )
}

#Preview("With Action") {
    EmptyStateView(
        icon: "tray.fill",
        title: "No Items",
        message: "Add items to this list to start tracking gifts",
        actionTitle: "Add Item"
    ) {
        print("Add item tapped")
    }
}
