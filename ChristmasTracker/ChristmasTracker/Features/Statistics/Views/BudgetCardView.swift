//
//  BudgetCardView.swift
//  ChristmasTracker
//
//  I5a Story C: the budget card (total, spent, remaining or "Over by", progress bar and one row per
//  person) and the "No budget for <year>" card. Over budget is shown in text and with the destructive
//  token, never by color alone. Amount rows reflow at large Dynamic Type so no amount is truncated.
//  The delete error of the card shows as an InlineErrorBanner inside the card.
//

import SwiftUI

struct BudgetCardView: View {
    @Bindable var model: StatsScreenModel
    let card: BudgetCardState

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            header
            BudgetAmountLine(title: "Total", value: card.totalText)
            BudgetAmountLine(title: "Spent", value: card.spentText)
            Text(card.statusText)
                .font(.appHeadline)
                .foregroundStyle(card.isOver ? Color.destructiveColor : Color.textPrimaryColor)
                .fixedSize(horizontal: false, vertical: true)
            ProgressView(value: card.progress)
                .tint(card.isOver ? Color.destructiveColor : Color.primaryColor)
                .accessibilityLabel("Budget progress")
                .accessibilityValue(card.progressAccessibilityLabel)
            if let cardBanner = model.budgetCardBanner {
                InlineErrorBanner(
                    state: cardBanner,
                    onTryAgain: { Task { await model.retryBudgetCardAction() } },
                    onDismiss: { model.dismissBudgetCardBanner() }
                )
            }
            if !card.rows.isEmpty {
                people
            }
        }
        .statsCardStyle()
    }

    private var header: some View {
        HStack(alignment: .center, spacing: AppSpacing.sm) {
            Text(verbatim: "\(card.year) Budget")
                .font(.appTitle3)
                .foregroundStyle(Color.textPrimaryColor)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: AppSpacing.sm)
            BudgetCardMenu(model: model, year: card.year)
        }
    }

    private var people: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Divider()
            ForEach(card.rows) { row in
                BudgetPersonRowView(row: row)
            }
        }
    }
}

struct BudgetPersonRowView: View {
    let row: BudgetPersonRowState

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(row.name)
                .font(.appHeadline)
                .foregroundStyle(Color.textPrimaryColor)
                .fixedSize(horizontal: false, vertical: true)
            BudgetAmountLine(title: "Limit", value: row.limitText)
            BudgetAmountLine(title: "Spent", value: row.spentText)
            Text(row.statusText)
                .font(.appSubheadline)
                .foregroundStyle(row.isOver ? Color.destructiveColor : Color.textMutedColor)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(row.accessibilityLabel)
    }
}

/// A title and an amount: side by side when they fit, stacked otherwise (large Dynamic Type).
struct BudgetAmountLine: View {
    let title: String
    let value: String

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            stacked
        } else {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline) {
                    titleText
                    Spacer(minLength: AppSpacing.sm)
                    valueText
                }
                stacked
            }
        }
    }

    private var stacked: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            titleText
            valueText
        }
    }

    private var titleText: some View {
        Text(title)
            .font(.appCallout)
            .foregroundStyle(Color.textMutedColor)
    }

    private var valueText: some View {
        Text(value)
            .font(.appBody)
            .foregroundStyle(Color.textPrimaryColor)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// The card of a year with purchases but no budget.
struct NoBudgetCardView: View {
    let title: String
    let createTitle: String
    let onCreate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text(title)
                .font(.appTitle3)
                .foregroundStyle(Color.textPrimaryColor)
                .accessibilityAddTraits(.isHeader)
            Text("Set a total and limits for the people you buy for to see how you are doing.")
                .font(.appBody)
                .foregroundStyle(Color.textMutedColor)
                .fixedSize(horizontal: false, vertical: true)
            CreateBudgetButton(title: createTitle, action: onCreate)
        }
        .statsCardStyle()
    }
}

struct CreateBudgetButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.appHeadline)
                .frame(maxWidth: .infinity, minHeight: InlineErrorBannerState.minimumButtonHeight)
        }
        .buttonStyle(.borderedProminent)
        .tint(Color.primaryColor)
    }
}

#Preview("Budget card") {
    BudgetCardView(model: BudgetCardPreview.model, card: BudgetCardPreview.card(over: false))
        .padding(AppSpacing.lg)
        .background(Color.backgroundPrimaryColor)
}

#Preview("Budget card, over, large type, dark") {
    BudgetCardView(model: BudgetCardPreview.model, card: BudgetCardPreview.card(over: true))
        .padding(AppSpacing.lg)
        .background(Color.backgroundPrimaryColor)
        .dynamicTypeSize(.accessibility3)
        .preferredColorScheme(.dark)
}

@MainActor
private enum BudgetCardPreview {
    static let model = StatsScreenModel(
        statsService: StatsService(repository: InertStatsLoader()),
        budgetService: BudgetService(repository: InertBudgetManager()),
        listService: ListService(repository: MockListRepository(), dataStore: ListDataStore()),
        now: { Date() },
        calendar: .current,
        currencyCode: "USD",
        locale: .current
    )

    static func card(over: Bool) -> BudgetCardState {
        let spent: Decimal = over ? 650 : 250
        let budget = Budget(
            id: "preview", year: 2026, totalBudget: 600, totalSpent: spent, remaining: 600 - spent,
            isOverBudget: over,
            recipients: [
                RecipientBudget(
                    id: "row", recipientId: "person", recipientName: "Tommy", maxSpend: 300, spent: spent,
                    remaining: 300 - spent, overage: over ? 350 : 0, isOverBudget: over
                )
            ],
            createdAt: Date(timeIntervalSince1970: 0), updatedAt: Date(timeIntervalSince1970: 0)
        )
        return BudgetCardState.make(from: budget, currencyCode: "USD", locale: .current)
    }
}
