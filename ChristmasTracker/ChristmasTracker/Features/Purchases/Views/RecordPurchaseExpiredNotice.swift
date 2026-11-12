//
//  RecordPurchaseExpiredNotice.swift
//  ChristmasTracker
//
//  The expired confirmation: the plain message and one button back to editing.
//

import SwiftUI

struct RecordPurchaseExpiredNotice: View {
    let onEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Label(RecordPurchaseCopy.expiredMessage, systemImage: "clock.badge.exclamationmark")
                .font(.appBody)
                .foregroundStyle(Color.textPrimaryColor)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: onEdit) {
                Text("Edit Details")
                    .font(.appHeadline)
                    .frame(maxWidth: .infinity, minHeight: InlineErrorBannerState.minimumButtonHeight)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.primaryColor)
        }
        .onAppear {
            AccessibilityNotification.Announcement(RecordPurchaseCopy.expiredMessage).post()
        }
    }
}
