//
//  PurchaseHistoryRowView.swift
//  ChristmasTracker
//
//  PH1-H3: one purchase in the history as a card button. Item name, who it is for, the date (and the
//  quantity above 1), the total and the shipping dot. At accessibility Dynamic Type sizes the parts
//  stack and the amount is never truncated. One accessibility element with the combined label.
//

import SwiftUI

struct PurchaseHistoryRowView: View {
    let row: PurchaseHistoryRow
    let onOpen: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale
    @Environment(\.calendar) private var calendar

    private var presentation: PurchaseHistoryRowPresentation {
        PurchaseHistoryRowPresentation.make(row, locale: locale, calendar: calendar)
    }

    var body: some View {
        Button(action: onOpen) {
            layout
                .frame(maxWidth: .infinity, minHeight: InlineErrorBannerState.minimumButtonHeight, alignment: .leading)
                .appCard()
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(presentation.accessibilityLabel)
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private var layout: some View {
        if dynamicTypeSize.isAccessibilitySize {
            stacked
        } else {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: AppSpacing.sm) {
                    details
                    Spacer(minLength: AppSpacing.sm)
                    amount
                }
                stacked
            }
        }
    }

    private var stacked: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            details
            amount
        }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(presentation.itemName)
                .font(.appHeadline)
                .foregroundStyle(Color.textPrimaryColor)
                .fixedSize(horizontal: false, vertical: true)
            Text(presentation.recipientText)
                .font(.appCallout)
                .foregroundStyle(Color.textMutedColor)
                .fixedSize(horizontal: false, vertical: true)
            Text(dateLine)
                .font(.appCallout)
                .foregroundStyle(Color.textMutedColor)
                .fixedSize(horizontal: false, vertical: true)
            StatusDotLabel(shipping: row.shippingStatus)
        }
    }

    private var dateLine: String {
        [presentation.dateText, presentation.quantityText].compactMap { $0 }.joined(separator: " · ")
    }

    private var amount: some View {
        Text(presentation.totalText)
            .font(.appBody)
            .foregroundStyle(Color.textPrimaryColor)
            .fixedSize(horizontal: false, vertical: true)
    }
}
