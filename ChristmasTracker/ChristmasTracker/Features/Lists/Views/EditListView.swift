//
//  EditListView.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/13/26.
//

import SwiftUI

struct EditListView: View {
    
    let list: ListDetail
    
    @Environment(\.listService) private var listService
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Form State
    @State private var name: String
    @State private var theme: String
    @State private var description: String
    @State private var visibility: ListVisibility
    
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    init(list: ListDetail) {
        self.list = list
        _name = State(initialValue: list.name)
        _theme = State(initialValue: list.theme ?? "")
        _description = State(initialValue: list.description ?? "")
        _visibility = State(initialValue: list.visibility)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("List Details") {
                    TextField("List Name", text: $name)
                        .autocorrectionDisabled()
                    TextField("Theme (optional)", text: $theme)
                        .autocorrectionDisabled()
                    HStack {
                        Text("Year")
                        Spacer()
                        Text("\(list.year)")
                            .foregroundColor(.textMutedColor)
                    }
                }
                Section("Recipient") {
                    HStack {
                        Text("Recipient")
                        Spacer()
                        Text(list.recipientName)
                            .foregroundColor(.textMutedColor)
                    }
                }
                Section("Description") {
                    TextField("Add notes or details (optional)", text: $description, axis: .vertical)
                            .lineLimit(3...6)
                }
                Section("Privacy") {
                    Picker("Visibility", selection: $visibility) {
                        Text("Private").tag(ListVisibility.private)
                        Text("Invite Only").tag(ListVisibility.inviteOnly)
                        Text("Public").tag(ListVisibility.public)
                    }
                }
            }
            .navigationTitle("Edit List")
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
    
    // MARK: - Validation
    private var isFormValid: Bool {
        !name.isEmpty
    }
    
    private var hasChanges: Bool {
        name != list.name ||
        theme != (list.theme ?? "") ||
        description != (list.description ?? "") ||
        visibility != list.visibility
    }
    
    // MARK: - Actions
    
    private func saveChanges() async {
        isSaving = true
        // Build request with only changed fields
        let request = UpdateListRequest(
            name: name != list.name ? name.trimmingCharacters(in: .whitespaces) : nil,
            theme: theme != (list.theme ?? "") ? (theme.isEmpty ? nil :
                                                    theme.trimmingCharacters(in: .whitespaces)) : nil,
            description: description != (list.description ?? "") ? (description.isEmpty ? nil :
                                                                        description.trimmingCharacters(in: .whitespaces)) : nil,
            visibility: visibility != list.visibility ? visibility : nil
        )
        do {
            try await listService.updateList(id: list.id, request)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        isSaving = false
    }
}


#Preview {
    EditListView(list: MockListData.allLists[0])
        .environment(\.listService, ListService(
            repository: MockListRepository(),
            dataStore: ListDataStore()
        ))
}
