//
//  PurchaseEditView.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/16/26.
//

import SwiftUI

struct EditPurchaseView: View {
    
    let purchase: Purchase
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var quantityText: String
    @State private var totalCostText: String
    @State private var storeName: String
    @State private var confirmationNumber: String
    @State private var trackingNumber: String
    @State private var notes: String
    @State private var shippingStatus: ShippingStatus
    
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    init(purchase: Purchase) {
        self.purchase = purchase
        _quantityText = State(initialValue: "\(purchase.quantity)")
        _totalCostText = State(initialValue: String(format: "%.2f", purchase.totalCost))
        _storeName = State(initialValue: purchase.storeName ?? "")
        _confirmationNumber = State(initialValue: purchase.confirmationNumber ?? "")
        _trackingNumber = State(initialValue: purchase.trackingNumber ?? "")
        _notes = State(initialValue: purchase.notes ?? "")
        _shippingStatus = State(initialValue: purchase.shippingStatus)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Purchase Details") {
                    HStack {
                        Text("Quantity:")
                        TextField("Quantity", text: $quantityText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("$")
                        TextField("Total Cost", text: $totalCostText)
                            .keyboardType(.decimalPad)
                    }
                    
                    if let quantity = parsedQuantity, let cost = parsedCost, quantity > 0 {
                        HStack {
                            Text("Unit Cost:")
                                .foregroundColor(.textMutedColor)
                            Spacer()
                            Text("$\(String(format: "%.2f", cost / Double(quantity)))")
                                .foregroundColor(.textPrimaryColor)
                        }
                        .font(.appCaption1)
                    }
                }
                
                Section("Shipping Status") {
                    Picker("Status", selection: $shippingStatus) {
                        ForEach([ShippingStatus.notShipped, .shipped, .delivered], id: \.self) { status in
                            HStack {
                                Image(systemName: status.icon)
                                Text(status.displayName)
                            }
                            .tag(status)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section("Store & Order Info") {
                    TextField("Store Name (optional)", text: $storeName)
                    TextField("Confirmation # (optional)", text: $confirmationNumber)
                    TextField("Tracking # (optional)", text: $trackingNumber)
                }
                
                Section("Notes") {
                    TextField("Additional notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Edit Purchase")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isSaving)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            await saveChanges()
                        }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Save")
                        }
                    }
                    .disabled(!hasChanges || !isFormValid || isSaving)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private var isFormValid: Bool {
        parsedQuantity != nil && parsedCost != nil
    }
    
    private var hasChanges: Bool {
        quantityText != "\(purchase.quantity)" ||
        totalCostText != String(format: "%.2f", purchase.totalCost) ||
        storeName != (purchase.storeName ?? "") ||
        confirmationNumber != (purchase.confirmationNumber ?? "") ||
        trackingNumber != (purchase.trackingNumber ?? "") ||
        notes != (purchase.notes ?? "") ||
        shippingStatus != purchase.shippingStatus
    }
    
    private var parsedQuantity: Int? {
        Int(quantityText)
    }
    
    private var parsedCost: Double? {
        Double(totalCostText)
    }
    
    private func saveChanges() async {
        guard let quantity = parsedQuantity,
              let cost = parsedCost else { return }
        
        isSaving = true
        
        let request = UpdatePurchaseRequest(
            quantity: quantity != purchase.quantity ? quantity : nil,
            totalCost: cost != purchase.totalCost ? cost : nil,
            storeName: storeName != (purchase.storeName ?? "") ? (storeName.isEmpty ? nil : storeName) : nil,
            notes: notes != (purchase.notes ?? "") ? (notes.isEmpty ? nil : notes) : nil,
            confirmationNumber: confirmationNumber != (purchase.confirmationNumber ?? "") ? (confirmationNumber.isEmpty ? nil : confirmationNumber) : nil,
            trackingNumber: trackingNumber != (purchase.trackingNumber ?? "") ? (trackingNumber.isEmpty ? nil : trackingNumber) : nil,
            shippingStatus: shippingStatus != purchase.shippingStatus ? shippingStatus : nil
        )
        
        do {
            // TODO: Update via PurchaseRepository
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        
        isSaving = false
    }
}

#Preview {
    EditPurchaseView(purchase: MockPurchaseData.allPurchases[0])
}
