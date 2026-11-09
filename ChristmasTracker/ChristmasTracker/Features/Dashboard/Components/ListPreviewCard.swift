//
//  ListPreviewCard.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/12/26.
//

import SwiftUI

/// One list on the dashboard. It shows what the row state allows and nothing else: when counts
/// are hidden the card has no note or placeholder about them.
struct ListPreviewCard: View {

    let state: ListRowState

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(alignment: .top, spacing: AppSpacing.md) {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(state.title)
                        .font(.appTitle3)
                        .foregroundStyle(Color.textPrimaryColor)
                    Text(state.subtitle)
                        .font(.appBody)
                        .foregroundStyle(Color.textMutedColor)
                }
                Spacer(minLength: AppSpacing.sm)
                ListBadge(title: state.badgeTitle, tone: state.badgeTone)
            }

            if let itemCountText = state.itemCountText, let purchasedCountText = state.purchasedCountText {
                Divider()
                ListCountsView(
                    itemCountText: itemCountText,
                    purchasedCountText: purchasedCountText,
                    progress: state.progress
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .listCard()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(state.accessibilityLabel)
        .accessibilityHint(state.accessibilityHint)
    }
}

#Preview {
    VStack {
        ListPreviewCard(state: ListRowState(list: MockListData.ownerOfChildList.asGiftList()))
        ListPreviewCard(state: ListRowState(list: MockListData.blindOwnerOfSelfList.asGiftList()))
    }
    .padding(EdgeInsets.appScreenPadding)
}
