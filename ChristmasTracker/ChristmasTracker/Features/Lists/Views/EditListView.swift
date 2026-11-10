//
//  EditListView.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/13/26.
//

import SwiftUI

/// Edits the name, theme and visibility of a list. Only changed fields are sent.
struct EditListView: View {

    let list: ListDetail

    @Environment(\.listService) private var listService
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var theme: String
    @State private var visibility: ListVisibility

    @State private var coOwnerEmail = ""
    @State private var removesCoOwner = false

    @State private var isSaving = false
    @State private var errorPresentation: ListErrorPresentation?

    init(list: ListDetail) {
        self.list = list
        _name = State(initialValue: list.name)
        _theme = State(initialValue: list.theme ?? "")
        _visibility = State(initialValue: list.visibility)
    }

    private var validity: EditFormValidity {
        ListFormValidation.validateEdit(name: name, theme: theme)
    }

    private var coOwnerState: CoOwnerSectionState {
        CoOwnerSectionState(detail: list)
    }

    private var hasCoOwnerEmail: Bool {
        !coOwnerEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// The co-owner part of the one update: a typed address (only when the flag offers the change)
    /// or a removal (only when offered), otherwise unchanged.
    private var coOwnerChange: CoOwnerChange {
        if coOwnerState.showsRemove, removesCoOwner { return .clear }
        if coOwnerState.showsChange, hasCoOwnerEmail {
            return CoOwnerFormValidation.makeChange(email: coOwnerEmail) ?? .unchanged
        }
        return .unchanged
    }

    private var coOwnerInputAllowsSave: Bool {
        guard coOwnerState.showsChange, hasCoOwnerEmail else { return true }
        return CoOwnerFormValidation.canSubmit(email: coOwnerEmail, isMutating: listService.isMutating)
    }

    private var pendingInput: UpdateListInput? {
        ListFormValidation.makeUpdateInput(
            original: list,
            name: name,
            theme: theme,
            visibility: visibility,
            coOwner: coOwnerChange
        )
    }

    private var canSave: Bool {
        validity.isValid && coOwnerInputAllowsSave && pendingInput != nil && !isSaving && !listService.isMutating
    }

    var body: some View {
        NavigationStack {
            Form {
                if let errorPresentation {
                    Section {
                        ListErrorBanner(
                            presentation: errorPresentation,
                            onRetry: { Task { await saveChanges() } },
                            onLeave: { dismiss() },
                            onDismiss: { self.errorPresentation = nil }
                        )
                    }
                }
                Section("List Details") {
                    TextField("List Name", text: $name)
                        .autocorrectionDisabled()
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("editList.nameField")
                    if validity.nameEmptyOrTooLong, !name.isEmpty {
                        problemText("Use 1 to \(ListFormValidation.nameLimit) characters.")
                    }
                    TextField("Theme (optional)", text: $theme)
                        .autocorrectionDisabled()
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("editList.themeField")
                    if validity.themeTooLong {
                        problemText("Use at most \(ListFormValidation.themeLimit) characters.")
                    }
                    LabeledContent("Year", value: list.year.yearDisplay)
                        .foregroundStyle(Color.textMutedColor)
                }
                Section("Recipient") {
                    LabeledContent("Recipient", value: list.recipientName)
                        .foregroundStyle(Color.textMutedColor)
                }
                coOwnerSection
                Section("Privacy") {
                    Picker("Visibility", selection: $visibility) {
                        ForEach(ListFormValidation.selectableVisibilities, id: \.self) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("editList.visibilityPicker")
                }
            }
            .font(.appBody)
            .scrollContentBackground(.hidden)
            .background(Color.backgroundPrimaryColor)
            .navigationTitle("Edit List")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: listService.goneListId) { _, goneId in
                if ListScreenExit.shouldDismissEdit(goneListId: goneId, editedListId: list.id) {
                    dismiss()
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .frame(minHeight: 44)
                    .disabled(isSaving)
                    .accessibilityIdentifier("editList.cancelButton")
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
                    .frame(minHeight: 44)
                    .disabled(!canSave)
                    .accessibilityIdentifier("editList.saveButton")
                }
            }
        }
    }

    @ViewBuilder
    private var coOwnerSection: some View {
        let state = coOwnerState
        if state.showsChange || state.currentCoOwnerName != nil {
            Section("Co-owner") {
                if let name = state.currentCoOwnerName {
                    LabeledContent("Current co-owner", value: name)
                        .foregroundStyle(Color.textMutedColor)
                }
                if state.showsChange {
                    TextField("Change co-owner email", text: $coOwnerEmail)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .disabled(removesCoOwner)
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("editList.coOwnerEmailField")
                    if hasCoOwnerEmail, !CoOwnerFormValidation.isValidEmail(coOwnerEmail) {
                        problemText("Enter a valid email address.")
                    }
                }
                if state.showsRemove {
                    Toggle("Remove co-owner", isOn: $removesCoOwner)
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("editList.removeCoOwnerToggle")
                }
            }
        }
    }

    private func problemText(_ text: String) -> some View {
        Text(text)
            .font(.appCaption1)
            .foregroundStyle(Color.accentColor)
    }

    // MARK: - Actions

    private func saveChanges() async {
        guard validity.isValid, let input = pendingInput else { return }
        isSaving = true
        errorPresentation = nil
        defer { isSaving = false }

        do {
            try await listService.updateList(id: list.id, input)
            dismiss()
        } catch is CancellationError {
            return
        } catch {
            let listError = (error as? ListError) ?? .server
            errorPresentation = ListErrorPresentation(listError)
            // The list is gone or read-only: close the sheet; the detail screen leaves as well.
            if ListScreenExit.shouldDismissEdit(for: listError) {
                dismiss()
            }
        }
    }
}

#Preview {
    EditListView(list: MockListData.ownerOfChildList)
        .environment(\.listService, ListService(
            repository: MockListRepository(),
            dataStore: ListDataStore()
        ))
}
