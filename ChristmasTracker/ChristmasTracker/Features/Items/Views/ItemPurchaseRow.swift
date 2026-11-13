//
//  ItemPurchaseRow.swift
//  ChristmasTracker
//
//  One row of the item detail's purchase card. A row the signed-in user may open (the row state's
//  canOpen) is a Button with a trailing chevron and the hint the row state provides; every other
//  row is plain text with no button and no action. This view never decides ownership.
//

import SwiftUI

struct ItemPurchaseRow: View {
    let row: PurchaseRowState
    let onOpen: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private static let chevronSymbol = "chevron.right"

    var body: some View {
        if row.canOpen {
            Button(action: onOpen) {
                rowContent(showsChevron: true)
            }
            .buttonStyle(.plain)
            .accessibilityHint(row.accessibilityHint ?? "")
        } else {
            rowContent(showsChevron: false)
        }
    }

    private func rowContent(showsChevron: Bool) -> some View {
        HStack(spacing: AppSpacing.sm) {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(row.purchaserName)
                    Text("\(row.quantity) for \(row.totalCostText)")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(row.purchaserName)
                Spacer()
                Text("\(row.quantity) for \(row.totalCostText)")
            }
            if showsChevron {
                Image(systemName: Self.chevronSymbol)
                    .font(.appCaption1)
                    .accessibilityHidden(true)
            }
        }
        .font(.appCaption1)
        .foregroundStyle(Color.textMutedColor)
        .frame(minHeight: showsChevron ? InlineErrorBannerState.minimumButtonHeight : nil)
        .contentShape(.rect)
    }
}

private enum ItemPurchaseRowPreviewData {
    static let openable = PurchaseRowState(
        id: "preview-1",
        quantity: 2,
        totalCostText: "$40.00",
        purchaserName: "Sample Purchaser",
        canOpen: true,
        accessibilityHint: "Sample hint"
    )
    static let plain = PurchaseRowState(
        id: "preview-2",
        quantity: 1,
        totalCostText: "$20.00",
        purchaserName: "Another Sample",
        canOpen: false,
        accessibilityHint: nil
    )
}

#Preview("Rows - light") {
    VStack(spacing: AppSpacing.md) {
        ItemPurchaseRow(row: ItemPurchaseRowPreviewData.openable, onOpen: {})
        ItemPurchaseRow(row: ItemPurchaseRowPreviewData.plain, onOpen: {})
    }
    .padding(AppSpacing.md)
    .preferredColorScheme(.light)
}

#Preview("Rows - large type") {
    VStack(spacing: AppSpacing.md) {
        ItemPurchaseRow(row: ItemPurchaseRowPreviewData.openable, onOpen: {})
        ItemPurchaseRow(row: ItemPurchaseRowPreviewData.plain, onOpen: {})
    }
    .padding(AppSpacing.md)
    .environment(\.dynamicTypeSize, .accessibility3)
}
