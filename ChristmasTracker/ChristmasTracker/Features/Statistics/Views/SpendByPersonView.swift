//
//  SpendByPersonView.swift
//  ChristmasTracker
//
//  I5a Story C: the "Spend by person" list of the Statistics tab. Each row is one accessibility
//  element; name, items and amount stack at large Dynamic Type so the amount is never truncated.
//

import SwiftUI

struct SpendByPersonView: View {
    let rows: [SpendRowState]

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Spend by person")
                .font(.appTitle3)
                .foregroundStyle(Color.textPrimaryColor)
                .accessibilityAddTraits(.isHeader)
            if rows.isEmpty {
                Text("No purchases yet.")
                    .font(.appBody)
                    .foregroundStyle(Color.textMutedColor)
            } else {
                ForEach(rows) { row in
                    SpendRowView(row: row)
                }
            }
        }
        .statsCardStyle()
    }
}

struct SpendRowView: View {
    let row: SpendRowState

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                stacked
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline, spacing: AppSpacing.sm) {
                        nameAndItems
                        Spacer(minLength: AppSpacing.sm)
                        amount
                    }
                    stacked
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(row.accessibilityLabel)
    }

    private var stacked: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            nameAndItems
            amount
        }
    }

    private var nameAndItems: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(row.name)
                .font(.appHeadline)
                .foregroundStyle(Color.textPrimaryColor)
                .fixedSize(horizontal: false, vertical: true)
            Text(row.itemsText)
                .font(.appCallout)
                .foregroundStyle(Color.textMutedColor)
        }
    }

    private var amount: some View {
        Text(row.spentText)
            .font(.appBody)
            .foregroundStyle(Color.textPrimaryColor)
            .fixedSize(horizontal: false, vertical: true)
    }
}

#Preview("Spend by person") {
    SpendByPersonView(
        rows: [
            SpendRowState(
                id: "a", name: "Tommy", spentText: "$150.50", itemsText: "2 items",
                accessibilityLabel: "Tommy, $150.50, 2 items"
            ),
            SpendRowState(
                id: "b", name: "Jordan Sample", spentText: "$79.99", itemsText: "1 item",
                accessibilityLabel: "Jordan Sample, $79.99, 1 item"
            )
        ]
    )
    .padding(AppSpacing.lg)
    .background(Color.backgroundPrimaryColor)
}
