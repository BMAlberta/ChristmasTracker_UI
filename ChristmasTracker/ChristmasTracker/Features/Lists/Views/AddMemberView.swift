//
//  AddMemberView.swift
//  ChristmasTracker
//
//  Sheet that adds a member or viewer to a list by email. The sheet owns its action and
//  dismisses itself on success.
//

import SwiftUI

struct AddMemberView: View {
    let listId: String

    @Environment(\.listService) private var listService
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var role: MemberRole = .member
    @State private var errorPresentation: ListErrorPresentation?

    private var canSubmit: Bool {
        AddMemberFormValidation.canSubmit(email: email, role: role, isMutating: listService.isMutating)
    }

    var body: some View {
        NavigationStack {
            Form {
                if let errorPresentation {
                    Section {
                        ListErrorBanner(
                            presentation: errorPresentation,
                            onRetry: { Task { await add() } },
                            onLeave: { dismiss() },
                            onDismiss: { self.errorPresentation = nil }
                        )
                    }
                }
                Section("Who to add") {
                    TextField("Email address", text: $email)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("addMember.emailField")
                    if !email.isEmpty, AddMemberFormValidation.validate(email: email, role: role).emailInvalid {
                        Text("Enter a valid email address.")
                            .font(.appCaption1)
                            .foregroundStyle(Color.accentColor)
                    }
                    Picker("Role", selection: $role) {
                        ForEach(MemberRole.allCases, id: \.self) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("addMember.rolePicker")
                }
            }
            .font(.appBody)
            .scrollContentBackground(.hidden)
            .background(Color.backgroundPrimaryColor)
            .navigationTitle("Add Member")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .frame(minHeight: 44)
                    .disabled(listService.isMutating)
                    .accessibilityIdentifier("addMember.cancelButton")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await add() }
                    } label: {
                        if listService.isMutating {
                            ProgressView()
                        } else {
                            Text("Add")
                        }
                    }
                    .frame(minHeight: 44)
                    .disabled(!canSubmit)
                    .accessibilityIdentifier("addMember.addButton")
                }
            }
        }
    }

    private func add() async {
        guard canSubmit else { return }
        errorPresentation = nil
        do {
            try await listService.addMember(
                listId: listId,
                AddMemberFormValidation.makeInput(email: email, role: role)
            )
            // If only the roster refresh failed the member is still added; pull to refresh catches up.
            dismiss()
        } catch is CancellationError {
            return
        } catch {
            errorPresentation = ListErrorPresentation((error as? ListError) ?? .server)
        }
    }
}
