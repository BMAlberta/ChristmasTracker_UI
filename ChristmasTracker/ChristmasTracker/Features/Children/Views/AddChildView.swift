//
//  AddChildView.swift
//  ChristmasTracker
//
//  Sheet that adds a child. The sheet owns its action and dismisses itself on success.
//

import SwiftUI

struct AddChildView: View {
    @Environment(\.childService) private var childService
    @Environment(\.dismiss) private var dismiss

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var displayName = ""
    @State private var relationship: ChildRelationship = .parent
    @State private var errorMessage: String?

    private var canSubmit: Bool {
        ChildFormValidation.canSubmit(
            firstName: firstName,
            lastName: lastName,
            displayName: displayName,
            isMutating: childService.isMutating
        )
    }

    private var validity: ChildFormValidity {
        ChildFormValidation.validate(firstName: firstName, lastName: lastName, displayName: displayName)
    }

    var body: some View {
        NavigationStack {
            Form {
                if let errorMessage {
                    Section {
                        Label {
                            Text(errorMessage)
                                .font(.appBody)
                                .foregroundStyle(Color.textPrimaryColor)
                        } icon: {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                }
                Section("Child") {
                    TextField("First name", text: $firstName)
                        .textContentType(.givenName)
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("addChild.firstNameField")
                    if validity.firstNameInvalid, !firstName.isEmpty {
                        problemText("Use 1 to \(ChildFormValidation.nameLimit) characters.")
                    }
                    TextField("Last name", text: $lastName)
                        .textContentType(.familyName)
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("addChild.lastNameField")
                    if validity.lastNameInvalid, !lastName.isEmpty {
                        problemText("Use 1 to \(ChildFormValidation.nameLimit) characters.")
                    }
                    TextField("Display name (optional)", text: $displayName)
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("addChild.displayNameField")
                    if validity.displayNameInvalid {
                        problemText("Use at most \(ChildFormValidation.displayNameLimit) characters.")
                    }
                    Picker("Relationship", selection: $relationship) {
                        ForEach(ChildRelationship.allCases, id: \.self) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("addChild.relationshipPicker")
                }
            }
            .font(.appBody)
            .scrollContentBackground(.hidden)
            .background(Color.backgroundPrimaryColor)
            .navigationTitle("Add Child")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .frame(minHeight: 44)
                    .disabled(childService.isMutating)
                    .accessibilityIdentifier("addChild.cancelButton")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await save() }
                    } label: {
                        if childService.isMutating {
                            ProgressView()
                        } else {
                            Text("Save")
                        }
                    }
                    .frame(minHeight: 44)
                    .disabled(!canSubmit)
                    .accessibilityIdentifier("addChild.saveButton")
                }
            }
        }
    }

    private func problemText(_ text: String) -> some View {
        Text(text)
            .font(.appCaption1)
            .foregroundStyle(Color.accentColor)
    }

    private func save() async {
        guard canSubmit else { return }
        errorMessage = nil
        do {
            try await childService.addChild(
                ChildFormValidation.makeInput(
                    firstName: firstName,
                    lastName: lastName,
                    displayName: displayName,
                    relationship: relationship
                )
            )
            dismiss()
        } catch is CancellationError {
            return
        } catch {
            errorMessage = ((error as? ChildError) ?? .server).userMessage
        }
    }
}
