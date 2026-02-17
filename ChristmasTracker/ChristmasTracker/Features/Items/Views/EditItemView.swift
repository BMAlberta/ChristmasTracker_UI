//
//  EditItemView.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/16/26.
//

import SwiftUI

import SwiftUI

struct EditItemView: View {
    
    let item: GiftItem
    
    @Environment(\.itemService) private var itemService
    @Environment(\.dismiss) private var dismiss
    
    // Form state
    @State private var name: String
    @State private var description: String
    @State private var url: String
    @State private var priceText: String
    @State private var quantityRequested: Int
    @State private var priority: Int
    
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    init(item: GiftItem) {
        self.item = item
        _name = State(initialValue: item.name)
        _description = State(initialValue: item.description ?? "")
        _url = State(initialValue: item.url ?? "")
        _priceText = State(initialValue: item.expectedUnitPrice != nil ? String(format: "%.2f", item.expectedUnitPrice!) : "")
        _quantityRequested = State(initialValue: item.quantityRequested)
        _priority = State(initialValue: item.priority)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Item Details") {
                    TextField("Item Name", text: $name)
                        .autocorrectionDisabled()
                    
                    TextField("Description (optional)", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section("Link") {
                    TextField("URL (optional)", text: $url)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                }
                
                Section("Pricing") {
                    HStack {
                        Text("$")
                        TextField("Price (optional)", text: $priceText)
                            .keyboardType(.decimalPad)
                    }
                    
                    Stepper("Quantity: \(quantityRequested)", value: $quantityRequested, in: 1...99)
                }
                
                Section("Priority") {
                    Stepper("Priority: \(priority)", value: $priority, in: 1...10)
                    HStack(spacing: 2) {
                        ForEach(1...10, id: \.self) { level in
                            Image(systemName: level <= priority ? "star.fill" : "star")
                                .foregroundColor(.orange)
                                .font(.appCaption2)
                        }
                    }
                }
                
                if item.offList {
                    Section {
                        HStack(spacing: AppSpacing.xs) {
                            Image(systemName: "gift.fill")
                            Text("This is a surprise gift")
                        }
                        .font(.appCaption1)
                        .foregroundColor(.orange)
                    }
                }
            }
            .navigationTitle("Edit Item")
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
        !name.isEmpty
    }
    
    private var hasChanges: Bool {
        name != item.name ||
        description != item.description ||
        url != (item.url ?? "") ||
        priceText != (item.expectedUnitPrice != nil ? String(format: "%.2f", item.expectedUnitPrice!) : "") ||
        quantityRequested != item.quantityRequested ||
        priority != item.priority
    }
    
    private var parsedPrice: Double? {
        guard !priceText.isEmpty else { return nil }
        return Double(priceText)
    }
    
    private func saveChanges() async {
        isSaving = true
        
        let request = UpdateItemRequest(
            name: name != item.name ? name.trimmingCharacters(in: .whitespaces) : nil,
            description: description != item.description ? description.trimmingCharacters(in: .whitespaces) : nil,
            url: url != (item.url ?? "") ? (url.isEmpty ? nil : url.trimmingCharacters(in: .whitespaces)) : nil,
            expectedUnitPrice: parsedPrice != item.expectedUnitPrice ? parsedPrice : nil,
            quantityRequested: quantityRequested != item.quantityRequested ? quantityRequested : nil,
            priority: priority != item.priority ? priority : nil,
            imageUrl: nil
        )
        
        do {
            try await itemService.updateItem(id: item.id, request)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        
        isSaving = false
    }
}

#Preview {
    EditItemView(item: MockItemData.allItems[0])
        .environment(\.itemService, ItemService(
            repository: MockItemRepository(),
            dataStore: ItemDataStore()
        ))
}
