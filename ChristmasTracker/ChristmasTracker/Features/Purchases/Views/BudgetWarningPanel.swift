//
//  BudgetWarningPanel.swift
//  ChristmasTracker
//
//  The inline budget warning inside the Record Purchase form: one row per warning, the notice
//  when present, then Record Anyway (prominent), Cancel and Edit Details. It is part of the form,
//  not an alert or a dialog. It receives only the pure panel state and three closures.
//

import SwiftUI

struct BudgetWarningPanel: View {
    let state: BudgetWarningPanelState
    let onCancel: () -> Void
    let onConfirm: () -> Void
    let onEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            if let notice = state.noticeText {
                Text(notice)
                    .font(.appBody)
                    .foregroundStyle(Color.textPrimaryColor)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(Array(state.rows.enumerated()), id: \.offset) { _, row in
                BudgetWarningRow(row: row)
            }
            VStack(spacing: AppSpacing.sm) {
                Button(action: onConfirm) {
                    Text(state.confirmTitle)
                        .font(.appHeadline)
                        .frame(maxWidth: .infinity, minHeight: InlineErrorBannerState.minimumButtonHeight)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.primaryColor)
                Button(action: onEdit) {
                    Text(state.editTitle)
                        .font(.appHeadline)
                        .frame(maxWidth: .infinity, minHeight: InlineErrorBannerState.minimumButtonHeight)
                }
                .buttonStyle(.bordered)
                .tint(Color.primaryColor)
                Button(action: onCancel) {
                    Text(state.cancelTitle)
                        .font(.appHeadline)
                        .frame(maxWidth: .infinity, minHeight: InlineErrorBannerState.minimumButtonHeight)
                }
                .buttonStyle(.bordered)
                .tint(Color.textMutedColor)
            }
        }
        .onAppear {
            AccessibilityNotification.Announcement(state.announcement).post()
        }
    }
}

private struct BudgetWarningRow: View {
    let row: BudgetWarningRowState

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Label(row.label, systemImage: "exclamationmark.triangle.fill")
                .font(.appHeadline)
                .foregroundStyle(Color.destructiveColor)
            LabeledContent("Budget limit", value: row.budgetLimitText)
            LabeledContent("Already spent", value: row.alreadySpentText)
            LabeledContent("This purchase", value: row.thisPurchaseText)
            LabeledContent("Over by", value: row.overByText)
        }
        .font(.appBody)
        .foregroundStyle(Color.textPrimaryColor)
        .accessibilityElement(children: .combine)
    }
}

#Preview("One recipient and one total warning, with notice") {
    Form {
        Section {
            BudgetWarningPanel(
                state: BudgetWarningPanelState(
                    warnings: [
                        BudgetWarning(
                            level: .recipient, recipientName: "Pat Recipient",
                            budgetLimit: 50, currentSpent: 40, purchaseAmount: 25.5, overage: 15.5
                        ),
                        BudgetWarning(
                            level: .total, recipientName: nil,
                            budgetLimit: 200, currentSpent: 190, purchaseAmount: 25.5, overage: 15.5
                        )
                    ],
                    notice: RecordPurchaseCopy.budgetChangedNotice
                ),
                onCancel: {}, onConfirm: {}, onEdit: {}
            )
        }
    }
}
