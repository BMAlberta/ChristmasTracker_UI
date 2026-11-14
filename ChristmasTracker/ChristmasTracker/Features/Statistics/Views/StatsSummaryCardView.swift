//
//  StatsSummaryCardView.swift
//  ChristmasTracker
//
//  I5a Story C: the summary card of the Statistics tab: total spent, items purchased and purchases.
//  The metrics sit side by side and stack when they do not fit (large Dynamic Type), so no amount is
//  truncated. The whole card is one accessibility element.
//

import SwiftUI

struct StatsSummaryCardView: View {
    let summary: StatsSummaryState

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            StatsMetricView(title: "Total spent", value: summary.totalSpentText, isProminent: true)
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    secondaryMetrics
                }
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: AppSpacing.xl) {
                        secondaryMetrics
                    }
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        secondaryMetrics
                    }
                }
            }
        }
        .statsCardStyle()
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var secondaryMetrics: some View {
        StatsMetricView(title: "Items purchased", value: summary.itemsPurchasedText, isProminent: false)
        StatsMetricView(title: "Purchases", value: summary.purchaseCountText, isProminent: false)
    }
}

private struct StatsMetricView: View {
    let title: String
    let value: String
    let isProminent: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(title)
                .font(.appCallout)
                .foregroundStyle(Color.textMutedColor)
            Text(value)
                .font(isProminent ? .appTitle1 : .appTitle3)
                .foregroundStyle(Color.textPrimaryColor)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

extension View {
    /// The card look shared by the Statistics cards: surface background, card padding, rounded corners.
    func statsCardStyle() -> some View {
        self
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(EdgeInsets.appCardPadding)
            .background(Color.surfaceColor, in: .rect(cornerRadius: AppSpacing.md))
    }
}

#Preview("Summary") {
    StatsSummaryCardView(
        summary: StatsSummaryState(totalSpentText: "$1,234.50", itemsPurchasedText: "12", purchaseCountText: "9")
    )
    .padding(AppSpacing.lg)
    .background(Color.backgroundPrimaryColor)
}

#Preview("Summary, large type, dark") {
    StatsSummaryCardView(
        summary: StatsSummaryState(totalSpentText: "$1,234.50", itemsPurchasedText: "12", purchaseCountText: "9")
    )
    .padding(AppSpacing.lg)
    .background(Color.backgroundPrimaryColor)
    .dynamicTypeSize(.accessibility3)
    .preferredColorScheme(.dark)
}
