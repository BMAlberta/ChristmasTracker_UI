//
//  RecordPurchaseFormFields.swift
//  ChristmasTracker
//
//  The editable fields of the Record Purchase form: quantity, total cost, the unit cost line
//  (only when valid) and the optional store, confirmation number, tracking number and notes.
//  Everything is disabled while the form is read-only (the confirmation binds quantity and amount).
//

import SwiftUI

struct RecordPurchaseFormFields: View {
    @Binding var input: RecordPurchaseFormInput
    let formState: RecordPurchaseFormState
    let isReadOnly: Bool

    var body: some View {
        Group {
            Section("Purchase") {
                Stepper(value: $input.quantity, in: 1...Int.max) {
                    Text("Quantity: \(input.quantity)")
                }
                TextField("Total cost", text: $input.totalCostText)
                    .keyboardType(.decimalPad)
                if showsCostHint {
                    Text("Enter an amount from 0.01 to 999,999.99 with at most two decimals.")
                        .font(.appCaption1)
                        .foregroundStyle(Color.destructiveColor)
                }
                if let unitCost = formState.unitCostText {
                    LabeledContent("Cost each", value: unitCost)
                }
            }
            Section("Details (optional)") {
                TextField("Store name", text: $input.storeName)
                TextField("Confirmation number", text: $input.confirmationNumber)
                TextField("Tracking number", text: $input.trackingNumber)
                TextField("Notes", text: $input.notes, axis: .vertical)
                    .lineLimit(2...5)
            }
        }
        .font(.appBody)
        .disabled(isReadOnly)
    }

    private var showsCostHint: Bool {
        !input.totalCostText.isEmpty && formState.totalCostInvalid
    }
}
