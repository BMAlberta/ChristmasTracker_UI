//
//  AddItemView.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/16/26.
//

import SwiftUI
struct AddItemView: View {
    let listId: String
    @Environment(\.itemService) private var itemService
    @Environment(\.dismiss) private var dismiss
    // Form state
    @State private var name: String = ""
    @State private var description: String = ""
    @State private var url: String = ""
    @State private var priceText: String = ""
    @State private var quantityRequested: Int = 1
    @State private var priority: Int = 5
    @State private var offList: Bool = false
    @State private var isCreating = false
    @State private var showError = false
    @State private var errorMessage = ""
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
                    Text("Add a link to the product")
                        .font(.appCaption1)
                        .foregroundColor(.textMutedColor)
                }
                Section("Pricing") {
                    HStack {
                        Text("$")
                        TextField("Price (optional)", text: $priceText)
                            .keyboardType(.decimalPad)
                    }
                    Stepper("Quantity: \(quantityRequested)", value: $quantityRequested, in:
                                1...99)
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
                    Text("1 = Low priority, 10 = High priority")
                        .font(.appCaption1)
                        .foregroundColor(.textMutedColor)
                }
                Section("Special Options") {
                    Toggle("Surprise Gift", isOn: $offList)
                    if offList {
                        Text("This item will be hidden from the list owner")
                            .font(.appCaption1)
                            .foregroundColor(.orange)
                    }
                }
            }
            .navigationTitle("Add Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isCreating)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            await createItem()
                        }
                    } label: {
                        if isCreating {
                            ProgressView()
                        } else {
                            Text("Add")
                        }
                    }
                    .disabled(!isFormValid || isCreating)
                    .alert("Error", isPresented: $showError) {
                        Button("OK") { }
                    } message: {
                        Text(errorMessage)
                    }
                }
            }
        }
    }
    
    private var isFormValid: Bool {
        !name.isEmpty
    }
    
    private var parsedPrice: Double? {
        guard !priceText.isEmpty else { return nil }
        return Double(priceText)
    }
    
    private func createItem() async {
        isCreating = true
        let request = CreateItemRequest(
            name: name.trimmingCharacters(in: .whitespaces),
            description: description.trimmingCharacters(in: .whitespaces), // Required, can be
            url: url.isEmpty ? nil : url.trimmingCharacters(in: .whitespaces),
            expectedUnitPrice: parsedPrice,
            quantityRequested: quantityRequested,
            priority: priority,
            offList: offList,
            imageUrl: nil
        )
        do {
            try await itemService.createItem(listId: listId, request)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        isCreating = false
    }
}
#Preview {
    AddItemView(listId: "1")
        .environment(\.itemService, ItemService(
            repository: MockItemRepository(),
            dataStore: ItemDataStore()
        ))
}
