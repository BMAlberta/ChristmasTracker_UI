//
//  AddItemView.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/16/26.
//

import SwiftUI

/// The add form. A creation error is held here, in local state, and shown in an inline banner;
/// it disappears on dismiss, a successful retry, closing the sheet, or leaving the screen.
struct AddItemView: View {
    let listId: String
    let context: ItemListContext

    @Environment(\.itemService) private var itemService
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var description = ""
    @State private var url = ""
    @State private var imageUrl = ""
    @State private var priceText = ""
    @State private var quantityRequested = 1
    @State private var priority = 5
    @State private var isCreating = false
    @State private var creationError: ItemError?

    private var permissions: ItemPermissions {
        ItemPermissions(capabilities: context.capabilities, currentUserId: nil)
    }

    private var input: CreateItemInput? {
        ItemFormValidation.makeCreateInput(
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
                if let banner = creationError.flatMap({ ItemErrorPresentation.banner(for: $0, hasRetryAction: true) }) {
                    Section {
                        InlineErrorBanner(
                            state: banner,
                            onTryAgain: { Task { await createItem() } },
                            onDismiss: { creationError = nil }
                        )
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    }
                }
                // An off-list item bought on creation needs an API decision first; if it is ever
                // built, its control goes here, after the form fields.
                ItemFormFields(
                    name: $name,
                    description: $description,
                    url: $url,
                    imageUrl: $imageUrl,
                    priceText: $priceText,
                    quantity: $quantityRequested,
                    priority: $priority,
                    showsOffListNotice: permissions.showsOffListNotice
                )
            }
            .navigationTitle("Add Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        creationError = nil
                        dismiss()
                    }
                    .disabled(isCreating)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await createItem() }
                    } label: {
                        if isCreating {
                            ProgressView()
                        } else {
                            Text("Add")
                        }
                    }
                    .disabled(input == nil || isCreating)
                }
            }
            .onDisappear {
                creationError = nil
            }
        }
    }

    private func createItem() async {
        guard let input, !isCreating else { return }
        creationError = nil
        isCreating = true
        defer { isCreating = false }
        do {
            try await itemService.createItem(listId: listId, input)
            dismiss()
        } catch is CancellationError {
            // The session ended or the task was cancelled: nothing to show.
        } catch {
            let itemError = (error as? ItemError) ?? ItemError.server
            if ItemErrorPresentation.leavesScreen(itemError) {
                dismiss()
            } else {
                creationError = itemError
            }
        }
    }
}

#Preview("Owner") {
    AddItemView(listId: "mock-list-child", context: ItemListContext(capabilities: MockListData.ownerCapabilities))
        .environment(\.itemService, ItemService(
            repository: MockItemRepository(),
            dataStore: ItemDataStore()
        ))
}

#Preview("Member (surprise item)") {
    AddItemView(listId: "mock-list-member", context: ItemListContext(capabilities: MockListData.memberCapabilities))
        .environment(\.itemService, ItemService(
            repository: MockItemRepository(),
            dataStore: ItemDataStore()
        ))
}
