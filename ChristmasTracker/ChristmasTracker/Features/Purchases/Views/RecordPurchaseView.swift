//
//  RecordPurchaseView.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/16/26.
//
//  The Record Purchase form, presented as a sheet from the item detail. Everything shown comes
//  from RecordPurchaseModel (itself gated by the list's capability flags). A purchase error is
//  held in the model and shown as an inline banner at the top of the form. The budget warning is
//  inline, not an alert. The view reports the end of the flow once through `onFinish`; the item
//  detail then runs the refreshes.
//

import SwiftUI

struct RecordPurchaseView: View {
    let item: ListItem
    let context: ItemListContext
    let onFinish: (RecordPurchaseFinish) -> Void

    @Environment(\.purchaseService) private var purchaseService

    var body: some View {
        RecordPurchaseContent(item: item, context: context, service: purchaseService, onFinish: onFinish)
    }
}

struct RecordPurchaseContent: View {
    let onFinish: (RecordPurchaseFinish) -> Void

    @State private var model: RecordPurchaseModel

    init(
        item: ListItem,
        context: ItemListContext,
        service: PurchaseService,
        onFinish: @escaping (RecordPurchaseFinish) -> Void
    ) {
        self.init(model: RecordPurchaseModel(item: item, context: context, service: service), onFinish: onFinish)
    }

    init(model: RecordPurchaseModel, onFinish: @escaping (RecordPurchaseFinish) -> Void) {
        self.onFinish = onFinish
        _model = State(initialValue: model)
    }

    var body: some View {
        NavigationStack {
            Form {
                if model.isAllowed {
                    formSections
                } else {
                    Section {
                        Text("You can't record purchases on this list.")
                            .font(.appBody)
                            .foregroundStyle(Color.textMutedColor)
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Record Purchase")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { model.cancel() }
                        .disabled(model.isSubmitting)
                }
            }
        }
        .interactiveDismissDisabled(model.isSubmitting)
        .onChange(of: model.finish) { _, finish in
            if let finish { onFinish(finish) }
        }
        .task(id: model.expiryDelay == nil ? -1 : model.awaitingEpoch) {
            await waitForExpiry()
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var formSections: some View {
        if let banner = model.errorBanner {
            Section {
                InlineErrorBanner(
                    state: banner,
                    onTryAgain: { Task { await model.retry() } },
                    onCheckItem: { model.checkItem() },
                    onRecordAgain: { Task { await model.recordAgain() } },
                    onDismiss: { model.dismissError() }
                )
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
        }
        if let summary = model.summary {
            summarySection(summary)
        }
        RecordPurchaseFormFields(
            input: $model.input,
            formState: model.formState,
            isReadOnly: model.fieldsAreReadOnly
        )
        if let panel = model.panel {
            Section {
                BudgetWarningPanel(
                    state: panel,
                    onCancel: { model.cancel() },
                    onConfirm: { Task { await model.confirmBudget() } },
                    onEdit: { model.editDetails() }
                )
            }
        } else if model.showsExpired {
            Section {
                RecordPurchaseExpiredNotice(onEdit: { model.editDetails() })
            }
        } else if model.showsRecordButton {
            RecordPurchaseRecordSection(model: model)
        }
    }

    private func summarySection(_ summary: RecordPurchaseItemSummary) -> some View {
        Section {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(summary.name)
                    .font(.appHeadline)
                    .foregroundStyle(Color.textPrimaryColor)
                Text(summary.requestedText)
                    .font(.appCallout)
                    .foregroundStyle(Color.textMutedColor)
                if let remaining = summary.remainingText {
                    Text(remaining)
                        .font(.appCallout)
                        .foregroundStyle(Color.textMutedColor)
                }
                if let price = summary.expectedPriceText {
                    Text("Expected price: \(price)")
                        .font(.appCallout)
                        .foregroundStyle(Color.textMutedColor)
                }
            }
        }
    }

    // MARK: - Expiry

    /// Sleeps until the pending confirmation expires, then tells the model. Ends quietly when cancelled.
    private func waitForExpiry() async {
        guard let delay = model.expiryDelay else { return }
        do {
            try await Task.sleep(for: delay)
        } catch {
            return
        }
        model.expiryReached()
    }
}
