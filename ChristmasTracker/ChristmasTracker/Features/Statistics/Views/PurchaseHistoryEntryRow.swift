//
//  PurchaseHistoryEntryRow.swift
//  ChristmasTracker
//
//  PH1-H3: the "Purchase History" card row at the end of the Statistics content. Same look as the
//  Profile rows: an icon, the title and a chevron on a card. One accessibility element. The icon and
//  chevron use text styles, so they scale with Dynamic Type.
//

import SwiftUI

struct PurchaseHistoryEntryRow: View {
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: AppSpacing.md) {
                Image(systemName: "bag")
                    .font(.appBody)
                    .foregroundStyle(Color.primaryColor)
                Text("Purchase History")
                    .font(.appBody)
                    .foregroundStyle(Color.textPrimaryColor)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: AppSpacing.sm)
                Image(systemName: "chevron.right")
                    .font(.appCaption1.weight(.semibold))
                    .foregroundStyle(Color.textMutedColor)
            }
            .frame(maxWidth: .infinity, minHeight: InlineErrorBannerState.minimumButtonHeight, alignment: .leading)
            .appCard()
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Purchase History")
        .accessibilityAddTraits(.isButton)
    }
}

#Preview("Entry row") {
    PurchaseHistoryEntryRow(onOpen: {})
        .padding(AppSpacing.lg)
        .background(Color.backgroundPrimaryColor)
}

#Preview("Entry row, large type, dark") {
    PurchaseHistoryEntryRow(onOpen: {})
        .padding(AppSpacing.lg)
        .background(Color.backgroundPrimaryColor)
        .dynamicTypeSize(.accessibility2)
        .preferredColorScheme(.dark)
}
