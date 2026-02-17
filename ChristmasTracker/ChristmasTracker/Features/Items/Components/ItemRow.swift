//
//  ItemRow.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/16/26.
//

import SwiftUI

struct ItemRow: View {
    let item: GiftItem
    let detail: ListDetail
    var body: some View {
        HStack(spacing: AppSpacing.md) {
            // Status icon
            statusIcon
            // Item info
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(item.name)
                    .font(.appBody)
                    .foregroundColor(item.isPurchased ? .textMutedColor : .textPrimaryColor)
                    .strikethrough(item.isPurchased)
                if let price = item.expectedUnitPrice {
                    Text("$\(String(format: "%.2f", price))")
                        .font(.appCaption1)
                        .foregroundColor(.textMutedColor)
                }
                // Status description
                statusDescription
            }
            Spacer()
            // Priority indicator
            if item.priority >= 8 {
                HStack(spacing: 2) {
                    ForEach(0..<min(item.priority, 10), id: \.self) { _ in
                        Image(systemName: "star.fill")
                            .font(.system(size: 8))
                            .foregroundColor(.orange)
                    }
                }
            }
            // Off-list badge
            if item.offList {
                Text("Surprise")
                    .font(.appCaption2)
                    .foregroundColor(.white)
                    .padding(.horizontal, AppSpacing.xs)
                    .padding(.vertical, 2)
                    .background(Color.orange)
                    .cornerRadius(4)
            }
            Image(systemName: "chevron.right")
                .font(.appCaption1)
                .foregroundColor(.textMutedColor)
        }
        .padding(.vertical, AppSpacing.sm)
        .contentShape(Rectangle())
    }
    private var statusIcon: some View {
        Image(systemName: item.status.icon)
            .font(.system(size: 24))
            .foregroundColor(item.status.color)
    }
    @ViewBuilder
    private var statusDescription: some View {
        switch item.status {
        case .available:
            EmptyView()
        case .partial:
            Text("Partially purchased")
                .font(.appCaption2)
                .foregroundColor(.orange)
        case .purchased:
            Text("Purchased")
                .font(.appCaption2)
                .foregroundColor(.green)
        case .wrapped:
            Text("Wrapped")
                .font(.appCaption2)
                .foregroundColor(.blue)
        case .gifted:
            Text("Gifted")
                .font(.appCaption2)
                .foregroundColor(.purple)
        }
    }
}
#Preview {
    VStack {
        ItemRow(
            item: MockItemData.allItems[0],
            detail: MockListData.allLists[0]
        )
        Divider()
        ItemRow(
            item: MockItemData.allItems[1],
            detail: MockListData.allLists[0]
        )
    }
    .padding()
    .environment(\.itemService, ItemService(
        repository: MockItemRepository(),
        dataStore: ItemDataStore()
    ))
}
