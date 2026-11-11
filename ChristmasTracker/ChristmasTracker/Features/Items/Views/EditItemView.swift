//
//  EditItemView.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/16/26.
//

import SwiftUI

/// The edit form. A save error is held here, in local state, and shown in an inline banner. A
/// "not found" means the item is gone, so the sheet closes (the detail screen closes with it).
struct EditItemView: View {
    let item: ListItem

    @Environment(\.itemService) private var itemService
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var description: String
    @State private var url: String
    @State private var imageUrl: String
    @State private var priceText: String
    @State private var quantityRequested: Int
    @State private var priority: Int
    @State private var isSaving = false
    @State private var saveError: ItemError?

    init(item: ListItem) {
        self.item = item
        _name = State(initialValue: item.name)
        _description = State(initialValue: item.description)
        _url = State(initialValue: item.url ?? "")
        _imageUrl = State(initialValue: item.imageUrl ?? "")
        _priceText = State(initialValue: item.expectedUnitPrice.map { "\($0)" } ?? "")
        _quantityRequested = State(initialValue: item.quantityRequested)
        _priority = State(initialValue: item.priority)
    }

    /// The changed fields, or nil when the form is invalid or nothing changed.
    private var input: UpdateItemInput? {
        ItemFormValidation.makeUpdateInput(
            original: item,
            name: name,
            description: description,
            url: url,
            imageUrl: imageUrl,
            priceText: priceText,
            quantity: quantityRequested,
            priority: priority
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                if let banner = saveError.flatMap({ ItemErrorPresentation.banner(for: $0, hasRetryAction: true) }) {
                    Section {
                        InlineErrorBanner(
                            state: banner,
                            onTryAgain: { Task { await saveChanges() } },
                            onDismiss: { saveError = nil }
                        )
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    }
                }
                ItemFormFields(
                    name: $name,
                    description: $description,
                    url: $url,
                    imageUrl: $imageUrl,
                    priceText: $priceText,
                    quantity: $quantityRequested,
                    priority: $priority
                )
            }
            .navigationTitle("Edit Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        saveError = nil
                        dismiss()
                    }
                    .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await saveChanges() }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Save")
                        }
                    }
                    .disabled(input == nil || isSaving)
                }
            }
            .onDisappear {
                saveError = nil
            }
        }
    }

    private func saveChanges() async {
        guard let input, !isSaving else { return }
        saveError = nil
        isSaving = true
        defer { isSaving = false }
        do {
            try await itemService.updateItem(id: item.id, input)
            dismiss()
        } catch is CancellationError {
            // The session ended or the task was cancelled: nothing to show.
        } catch {
            let itemError = (error as? ItemError) ?? ItemError.server
            if ItemErrorPresentation.leavesScreen(itemError) {
                dismiss()
            } else {
                saveError = itemError
            }
        }
    }
}

#Preview {
    EditItemView(item: MockItemSeed.items[0])
        .environment(\.itemService, ItemService(
            repository: MockItemRepository(),
            dataStore: ItemDataStore()
        ))
}
