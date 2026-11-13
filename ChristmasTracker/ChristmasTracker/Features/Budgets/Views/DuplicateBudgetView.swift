//
//  DuplicateBudgetView.swift
//  ChristmasTracker
//
//  I5a Story C: the small sheet that copies a budget to a year without one. The sheet owns its model
//  and its actions: Duplicate calls the model and, on success, reports the new budget and dismisses;
//  Cancel dismisses. A failure shows as an InlineErrorBanner inside the sheet.
//

import SwiftUI

struct DuplicateBudgetView: View {
    @State private var model: DuplicateBudgetModel
    let onDuplicated: (Budget) -> Void

    @Environment(\.dismiss) private var dismiss

    init(model: DuplicateBudgetModel, onDuplicated: @escaping (Budget) -> Void) {
        _model = State(initialValue: model)
        self.onDuplicated = onDuplicated
    }

    var body: some View {
        NavigationStack {
            Form {
                if let sheetBanner = model.banner {
                    Section {
                        InlineErrorBanner(
                            state: sheetBanner,
                            onTryAgain: { duplicate() },
                            onDismiss: { model.dismissBanner() }
                        )
                    }
                }
                Section {
                    yearPicker
                } header: {
                    Text(verbatim: "Copy the \(model.sourceYear) budget to")
                } footer: {
                    Text("The total and the limits are copied. Purchases are not.")
                }
                Section {
                    Button(action: { duplicate() }) {
                        Text("Duplicate")
                            .font(.appHeadline)
                            .frame(maxWidth: .infinity, minHeight: InlineErrorBannerState.minimumButtonHeight)
                    }
                    .disabled(!model.canDuplicate)
                }
            }
            .navigationTitle("Duplicate Budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(model.isDuplicating)
                }
            }
            .interactiveDismissDisabled(model.isDuplicating)
        }
        .presentationDetents([.medium, .large])
    }

    @ViewBuilder
    private var yearPicker: some View {
        if model.years.isEmpty {
            Text("No year is available to copy to.")
                .font(.appBody)
                .foregroundStyle(Color.textMutedColor)
        } else {
            Picker("Year", selection: yearBinding) {
                ForEach(model.years, id: \.self) { year in
                    Text(verbatim: String(year)).tag(Optional(year))
                }
            }
        }
    }

    private var yearBinding: Binding<Int?> {
        Binding(get: { model.selectedYear }, set: { model.selectedYear = $0 })
    }

    private func duplicate() {
        Task {
            guard let copy = await model.duplicate() else { return }
            onDuplicated(copy)
            dismiss()
        }
    }
}
