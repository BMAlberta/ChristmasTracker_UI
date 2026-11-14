//
//  BudgetEditorView.swift
//  ChristmasTracker
//
//  I5a Story C: the budget editor sheet (create and edit). The sheet owns its model and its actions:
//  Save calls the model and, on success, reports the stored budget and dismisses; Cancel dismisses.
//  A save error shows as an InlineErrorBanner inside the sheet. The person rows reflow at large
//  Dynamic Type so no amount is truncated. The model holds all logic; this view renders state.
//

import SwiftUI

struct BudgetEditorView: View {
    @State private var model: BudgetEditorModel
    let onSaved: (Budget) -> Void

    @Environment(\.dismiss) private var dismiss

    init(model: BudgetEditorModel, onSaved: @escaping (Budget) -> Void) {
        _model = State(initialValue: model)
        self.onSaved = onSaved
    }

    var body: some View {
        NavigationStack {
            Form {
                if let sheetBanner = model.banner {
                    Section {
                        InlineErrorBanner(
                            state: sheetBanner,
                            onTryAgain: { save() },
                            onDismiss: { model.dismissBanner() }
                        )
                    }
                }
                if model.isYearEditable {
                    yearSection
                }
                totalSection
                peopleSection
            }
            .navigationTitle(model.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .task { await model.loadOptions() }
            .interactiveDismissDisabled(model.isSaving)
            .scrollDismissesKeyboard(.interactively)
        }
    }

    // MARK: - Sections

    private var yearSection: some View {
        Section("Year") {
            if model.availableYears.isEmpty {
                Text("No year is available for a new budget.")
                    .font(.appBody)
                    .foregroundStyle(Color.textMutedColor)
            } else {
                Picker("Year", selection: yearBinding) {
                    ForEach(model.availableYears, id: \.self) { year in
                        Text(verbatim: String(year)).tag(year)
                    }
                }
            }
        }
    }

    private var totalSection: some View {
        Section("Total budget") {
            TextField("Total budget", text: totalBinding)
                .keyboardType(.decimalPad)
                .font(.appBody)
                .frame(minHeight: InlineErrorBannerState.minimumButtonHeight)
            if showsTotalHint {
                AmountHint()
            }
        }
    }

    private var peopleSection: some View {
        Section("Limits by person") {
            ForEach(model.draft.recipients) { person in
                BudgetPersonLimitRow(
                    name: person.name,
                    limitText: limitBinding(for: person.recipientId),
                    showsHint: showsLimitHint(for: person),
                    onRemove: { model.removePerson(recipientId: person.recipientId) }
                )
            }
            picker
            if let line = model.summaryLine {
                Text(line)
                    .font(.appCallout)
                    .foregroundStyle(model.summaryIsError ? Color.destructiveColor : Color.textMutedColor)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private var picker: some View {
        switch model.picker {
        case .loading:
            HStack(spacing: AppSpacing.sm) {
                ProgressView()
                Text("Loading people...")
                    .font(.appBody)
                    .foregroundStyle(Color.textMutedColor)
            }
        case .failed(let reason):
            InlineErrorBanner(
                state: InlineErrorBannerState(message: reason, actions: [.tryAgain]),
                onTryAgain: { Task { await model.loadOptions() } }
            )
            Text("You can still save a budget with just a total.")
                .font(.appCallout)
                .foregroundStyle(Color.textMutedColor)
        case .ready(let options):
            if options.isEmpty {
                Text("Nobody to add yet")
                    .font(.appBody)
                    .foregroundStyle(Color.textMutedColor)
            } else {
                addPersonMenu(options)
            }
        }
    }

    private func addPersonMenu(_ options: [BudgetRecipientOption]) -> some View {
        Menu {
            ForEach(options) { option in
                Button(option.displayName) { model.addPerson(option) }
            }
        } label: {
            Label("Add person", systemImage: "person.badge.plus")
                .font(.appBody)
                .frame(minHeight: InlineErrorBannerState.minimumButtonHeight)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { dismiss() }
                .disabled(model.isSaving)
        }
        ToolbarItem(placement: .confirmationAction) {
            if model.isSaving {
                ProgressView()
            } else {
                Button("Save") { save() }
                    .disabled(!model.canSave)
            }
        }
    }

    // MARK: - Actions

    private func save() {
        Task {
            guard let saved = await model.save() else { return }
            onSaved(saved)
            dismiss()
        }
    }

    // MARK: - Bindings and hints

    private var yearBinding: Binding<Int> {
        Binding(get: { model.draft.year }, set: { model.setYear($0) })
    }

    private var totalBinding: Binding<String> {
        Binding(get: { model.draft.totalText }, set: { model.setTotalText($0) })
    }

    private func limitBinding(for recipientId: String) -> Binding<String> {
        Binding(
            get: { model.draft.recipients.first { $0.recipientId == recipientId }?.limitText ?? "" },
            set: { model.setLimitText($0, for: recipientId) }
        )
    }

    private var showsTotalHint: Bool {
        !model.draft.totalText.isEmpty && model.validation.issues.contains(.totalInvalid)
    }

    private func showsLimitHint(for person: BudgetRecipientDraft) -> Bool {
        !person.limitText.isEmpty && model.validation.issues.contains(.limitInvalid(recipientId: person.recipientId))
    }
}

/// One person of the draft: the name, the limit field and a remove button. Stacks at large Dynamic Type.
private struct BudgetPersonLimitRow: View {
    let name: String
    @Binding var limitText: String
    let showsHint: Bool
    let onRemove: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    nameText
                    HStack(spacing: AppSpacing.sm) {
                        limitField
                        removeButton
                    }
                }
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: AppSpacing.sm) {
                        nameText
                        Spacer(minLength: AppSpacing.sm)
                        limitField
                        removeButton
                    }
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        nameText
                        HStack(spacing: AppSpacing.sm) {
                            limitField
                            removeButton
                        }
                    }
                }
            }
            if showsHint {
                AmountHint()
            }
        }
    }

    private var nameText: some View {
        Text(name)
            .font(.appBody)
            .foregroundStyle(Color.textPrimaryColor)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var limitField: some View {
        TextField("Limit", text: $limitText)
            .keyboardType(.decimalPad)
            .font(.appBody)
            .multilineTextAlignment(.trailing)
            .frame(minHeight: InlineErrorBannerState.minimumButtonHeight)
            .accessibilityLabel("Limit for \(name)")
    }

    private var removeButton: some View {
        Button(role: .destructive, action: onRemove) {
            Image(systemName: "minus.circle")
                .foregroundStyle(Color.destructiveColor)
                .frame(
                    minWidth: InlineErrorBannerState.minimumButtonHeight,
                    minHeight: InlineErrorBannerState.minimumButtonHeight
                )
                .contentShape(.rect)
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("Remove \(name)")
    }
}

/// The hint under an amount field that does not parse.
private struct AmountHint: View {
    var body: some View {
        Text("Enter an amount from 0 to 999,999.99 with at most two decimals.")
            .font(.appCaption1)
            .foregroundStyle(Color.destructiveColor)
            .fixedSize(horizontal: false, vertical: true)
    }
}
