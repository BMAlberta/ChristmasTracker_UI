//
//  ItemRow.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/16/26.
//

import SwiftUI

/// One item in the list. Driven only by `ItemRowState`: the status marker is present only when
/// the viewer may see gift activity, so this view never decides that itself.
struct ItemRow: View {
    let state: ItemRowState

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            if ThumbnailLayout.rowThumbnailVisible(for: dynamicTypeSize) {
                ItemThumbnail(imageUrl: state.imageUrl)
            }
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(state.name)
                    .font(.appBody)
                    .foregroundStyle(state.isCompleted ? Color.textMutedColor : Color.textPrimaryColor)
                    .strikethrough(state.isCompleted)
                details
                if let marker = state.statusMarker {
                    StatusPill(status: marker)
                }
            }
            Spacer(minLength: AppSpacing.sm)
            if state.showsOffListBadge {
                Text("Surprise")
                    .font(.appCaption2)
                    .foregroundStyle(Color.textPrimaryColor)
                    .padding(.horizontal, AppSpacing.xs)
                    .padding(.vertical, AppSpacing.xs)
                    .background(Color.highlightColor, in: .rect(cornerRadius: AppSpacing.xs))
            }
            Image(systemName: "chevron.right")
                .font(.appCaption1)
                .foregroundStyle(Color.textMutedColor)
                .accessibilityHidden(true)
        }
        .padding(.vertical, AppSpacing.sm)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }

    private var details: some View {
        HStack(spacing: AppSpacing.sm) {
            if let price = state.priceText {
                Text(price)
            }
            Text(state.quantityText)
            Text(state.priorityText)
        }
        .font(.appCaption1)
        .foregroundStyle(Color.textMutedColor)
    }
}

#Preview("Rows") {
    VStack {
        ItemRow(state: ItemRowState(
            id: "1", name: "Toy Rocket", priceText: "$24.99", quantityText: "Qty 1", priorityText: "Priority 9",
            statusMarker: .purchased, showsOffListBadge: false, isCompleted: true
        ))
        Divider()
        ItemRow(state: ItemRowState(
            id: "2", name: "Surprise Scooter", priceText: nil, quantityText: "Qty 1", priorityText: "Priority 5",
            statusMarker: nil, showsOffListBadge: true, isCompleted: false
        ))
    }
    .padding()
}
