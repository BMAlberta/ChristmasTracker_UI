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
    @State private var isCreating = false
    @State private var showError = false
    @State private var errorMessage = ""
    var body: some View {
        NavigationStack {
            Form {
                Section("Item Details") {
                    TextField("Item Name", text: $name)
                        .autocorrectionDisabled()
                    TextField("Description", text: $description, axis: .vertical)
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
        makeInput() != nil
    }

    private func makeInput() -> CreateItemInput? {
        ItemFormValidation.makeCreateInput(
            name: name,
            description: description,
            url: url,
            imageUrl: "",
            priceText: priceText,
            quantity: quantityRequested,
            priority: priority
        )
    }

    private func createItem() async {
        guard let input = makeInput() else { return }
        isCreating = true
        do {
            try await itemService.createItem(listId: listId, input)
            dismiss()
        } catch is CancellationError {
            // The session ended or the task was cancelled: nothing to show.
        } catch {
            errorMessage = (error as? ItemError)?.userMessage ?? ItemError.server.userMessage
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
