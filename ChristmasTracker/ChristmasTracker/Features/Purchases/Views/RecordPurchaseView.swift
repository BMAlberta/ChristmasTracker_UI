//
//  RecordPurchaseView.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/16/26.
//

import SwiftUI

struct RecordPurchaseView: View {
    
    let item: GiftItem
    
    @Environment(\.itemService) private var itemService
    @Environment(\.dismiss) private var dismiss
    
    @State private var quantity: Int
    @State private var totalCostText: String = ""
    @State private var storeName: String = ""
    @State private var confirmationNumber: String = ""
    @State private var trackingNumber: String = ""
    @State private var notes: String = ""
    
    @State private var isRecording = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    // Budget warning state
    @State private var pendingWarning: PurchaseWarning?
    @State private var showBudgetWarning = false
    
    // Over-purchase warning state
    @State private var showOverPurchaseWarning = false
    
    init(item: GiftItem) {
        self.item = item
        // Default to remaining quantity
        let remaining = item.quantityRequested - (item.totalQuantityPurchased ?? 0)
        _quantity = State(initialValue: max(1, remaining))
    }
    
    private var remainingQuantity: Int {
        item.quantityRequested - (item.totalQuantityPurchased ?? 0)
    }
    
    private var willOverPurchase: Bool {
        quantity > remainingQuantity
    }

    var body: some View {
        NavigationStack {
            Form {
                itemSummarySection
                purchaseDetailsSection
                storeOrderSection
                notesSection
                afterPurchaseSection
            }
            .navigationTitle("Record Purchase")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isRecording)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            await handleRecordPurchase()
                        }
                    } label: {
                        if isRecording {
                            ProgressView()
                        } else {
                            Text("Record")
                        }
                    }
                    .disabled(!isFormValid || isRecording)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .alert("Purchase Exceeds Request", isPresented: $showOverPurchaseWarning) {
                Button("Cancel", role: .cancel) { }
                Button("Continue Anyway") {
                    Task {
                        await recordPurchase(confirmationToken: nil)
                    }
                }
            } message: {
                Text("This will result in \((item.totalQuantityPurchased ?? 0) + quantity) purchased, but only \(item.quantityRequested) was requested. Multiple people may be purchasing this item.")
            }
            .alert("Budget Warning", isPresented: $showBudgetWarning) {
                Button("Cancel", role: .cancel) {
                    pendingWarning = nil
                    isRecording = false
                }
                Button("Continue Anyway") {
                    if let token = pendingWarning?.confirmationToken {
                        Task {
                            await recordPurchase(confirmationToken: token)
                        }
                    }
                }
            } message: {
                budgetWarningMessage
            }
        }
    }

    private var itemSummarySection: some View {
        Section {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text(item.name)
                    .font(.appHeadline)
                    .foregroundColor(.textPrimaryColor)

                HStack {
                    Text("Requested:")
                    Spacer()
                    Text("\(item.quantityRequested)")
                        .foregroundColor(.textMutedColor)
                }
                .font(.appCaption1)

                HStack {
                    Text("Already purchased:")
                    Spacer()
                    Text("\(item.totalQuantityPurchased ?? 0)")
                        .foregroundColor(.textMutedColor)
                }
                .font(.appCaption1)

                if let expectedPrice = item.expectedUnitPrice {
                    HStack {
                        Text("Expected price:")
                        Spacer()
                        Text("$\(String(format: "%.2f", expectedPrice))")
                            .foregroundColor(.textMutedColor)
                    }
                    .font(.appCaption1)
                }
            }
        }
    }

    private var purchaseDetailsSection: some View {
        Section("Purchase Details") {
            // ✅ UPDATED: Allow any quantity (optimistic concurrency)
            Stepper("Quantity: \(quantity)", value: $quantity, in: 1...99)

            HStack {
                Text("$")
                TextField("Total Cost", text: $totalCostText)
                    .keyboardType(.decimalPad)
            }

            if let parsed = parsedCost, quantity > 0 {
                HStack {
                    Text("Unit Cost:")
                        .foregroundColor(.textMutedColor)
                    Spacer()
                    Text("$\(String(format: "%.2f", parsed / Double(quantity)))")
                        .foregroundColor(.textPrimaryColor)
                }
                .font(.appCaption1)
            }
        }
    }

    private var storeOrderSection: some View {
        Section("Store & Order Info") {
            TextField("Store Name (optional)", text: $storeName)
                .autocorrectionDisabled()

            TextField("Confirmation # (optional)", text: $confirmationNumber)
                .autocorrectionDisabled()

            TextField("Tracking # (optional)", text: $trackingNumber)
                .autocorrectionDisabled()
        }
    }

    private var notesSection: some View {
        Section("Notes") {
            TextField("Additional notes (optional)", text: $notes, axis: .vertical)
                .lineLimit(3...6)
        }
    }

    private var afterPurchaseSection: some View {
        Section {
            HStack {
                Text("After this purchase:")
                Spacer()
                Text("\((item.totalQuantityPurchased ?? 0) + quantity) of \(item.quantityRequested)")
                    .foregroundColor(willOverPurchase ? .orange : .textPrimaryColor)
            }
            .font(.appCaption1)

            // ✅ NEW: Over-purchase warning
            if willOverPurchase {
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("This will exceed the requested quantity")
                        .font(.appCaption1)
                        .foregroundColor(.orange)
                }
            }
        }
    }

    private var budgetWarningMessage: some View {
        Group {
            if let warning = pendingWarning {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(warning.message)

                    if let summary = warning.details?.budgetSummary {
                        Text(summary)
                            .font(.appCaption1)
                    }
                }
            }
        }
    }
    
    private var isFormValid: Bool {
        !totalCostText.isEmpty && parsedCost != nil && quantity > 0
    }
    
    private var parsedCost: Double? {
        Double(totalCostText)
    }
    
    // ✅ NEW: Handle over-purchase warning first
    private func handleRecordPurchase() async {
        // Check for over-purchase
        if willOverPurchase && !showOverPurchaseWarning {
            showOverPurchaseWarning = true
            return
        }
        
        // Proceed to actual recording
        await recordPurchase(confirmationToken: nil)
    }
    
    // ✅ UPDATED: Handle budget warnings and confirmation tokens
    private func recordPurchase(confirmationToken: String?) async {
        guard let cost = parsedCost else { return }
        
        isRecording = true
        showOverPurchaseWarning = false  // Clear over-purchase warning
        
        let request = CreatePurchaseRequest(
            quantity: quantity,
            totalCost: cost,
            storeName: storeName.isEmpty ? nil : storeName.trimmingCharacters(in: .whitespaces),
            notes: notes.isEmpty ? nil : notes.trimmingCharacters(in: .whitespaces),
            confirmationNumber: confirmationNumber.isEmpty ? nil : confirmationNumber.trimmingCharacters(in: .whitespaces),
            trackingNumber: trackingNumber.isEmpty ? nil : trackingNumber.trimmingCharacters(in: .whitespaces),
            confirmationToken: confirmationToken  // ✅ Include token if retrying
        )
        
        do {
            // TODO: Call purchase repository via service
            // For now, this is a placeholder showing the pattern
            
            // let response = try await purchaseRepository.createPurchase(itemId: item.id, request)
            
            // if response.data.requiresConfirmation,
            //    let warning = response.warnings?.first(where: { $0.requiresConfirmation }) {
            //     // Show budget warning
            //     pendingWarning = warning
            //     showBudgetWarning = true
            //     isRecording = false
            //     return
            // }
            
            // Success - refresh items
//            if listId = item.listId {
            await itemService.loadItems(listId: item.listId)
//            }
            
            dismiss()
            
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        
        isRecording = false
    }
}

#Preview {
    RecordPurchaseView(item: MockItemData.allItems[1])
        .environment(\.itemService, ItemService(
            repository: MockItemRepository(),
            dataStore: ItemDataStore()
        ))
}
