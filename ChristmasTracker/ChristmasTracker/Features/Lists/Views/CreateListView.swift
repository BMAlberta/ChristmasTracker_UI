//
//  CreateListView.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/13/26.
//

import SwiftUI

/// Creates a list for yourself or for one of your children.
struct CreateListView: View {

    @Environment(\.listService) private var listService
    @Environment(\.authenticationService) private var authenticationService
    @Environment(\.childService) private var childService
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var theme: String = ""
    @State private var visibility: ListVisibility = .private
    @State private var year: Int = Calendar.current.component(.year, from: Date())

    @State private var selectedRecipientId: String?

    @State private var isCreating = false
    @State private var errorBanner: InlineErrorBannerState?
    @State private var dismissedLoads = DismissedLoads()

    private var validity: CreateFormValidity {
        ListFormValidation.validateCreate(name: name, theme: theme, year: year)
    }

    private var recipientOptions: CreateListRecipientOptions {
        CreateListRecipientOptions(
            currentUserId: authenticationService.currentUser?.id ?? "",
            children: childService.children,
            phase: childService.phase
        )
    }

    /// A failed children load: the picker offers no children then, so there is nothing saved to show.
    private var childrenLoad: ScreenLoadPresentation {
        ChildrenLoadState.make(phase: childService.phase, hasChildren: false, dismissed: dismissedLoads)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.xl) {
                    if let errorBanner {
                        InlineErrorBanner(
                            state: errorBanner,
                            onTryAgain: { Task { await createList() } },
                            onDismiss: { self.errorBanner = nil }
                        )
                    }
                    recipientCard
                    listDetailsCard
                    visibilityCard
                    yearCard
                }
                .padding(EdgeInsets.appScreenPadding)
            }
            .background(Color.backgroundPrimaryColor)
            .navigationTitle("New List")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await childService.loadChildren()
            }
            .onDisappear {
                errorBanner = nil
                dismissedLoads.reset()
                childService.clearLoadFailure()
            }
            .onChange(of: recipientOptions) { _, options in
                selectedRecipientId = options.resolvedSelection(current: selectedRecipientId)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .frame(minHeight: 44)
                    .disabled(isCreating)
                    .accessibilityIdentifier("createList.cancelButton")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await createList() }
                    } label: {
                        if isCreating {
                            ProgressView()
                        } else {
                            Text("Create")
                        }
                    }
                    .frame(minHeight: 44)
                    .disabled(!validity.isValid || isCreating)
                    .accessibilityIdentifier("createList.createButton")
                }
            }
        }
    }

    // MARK: - Cards

    private var recipientCard: some View {
        let options = recipientOptions
        let selection = Binding<String>(
            get: { options.resolvedSelection(current: selectedRecipientId) },
            set: { selectedRecipientId = $0 }
        )
        return VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Who is it for?")
                .font(.appHeadline)
                .foregroundStyle(Color.textPrimaryColor)

            Picker("Recipient", selection: selection) {
                ForEach(options.options) { option in
                    Text(option.title).tag(option.id)
                }
            }
            .pickerStyle(.menu)
            .frame(minHeight: 44)
            .accessibilityIdentifier("createList.recipientPicker")

            if options.showsLoading {
                ProgressView()
                    .accessibilityLabel("Loading your children")
            }
            if let childrenFailure = childrenLoad.fullError {
                InlineErrorBanner(
                    state: LoadBannerPresentation.state(for: childrenFailure),
                    onTryAgain: {
                        dismissedLoads.reset()
                        Task { await childService.loadChildren() }
                    },
                    onDismiss: { dismissedLoads.dismiss(childrenFailure.retryTargets) }
                )
            }
            if options.showsEmptyHint {
                Text("Children you add in your profile can be chosen here.")
                    .font(.appCaption1)
                    .foregroundStyle(Color.textMutedColor)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .listCard()
    }

    private var listDetailsCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("List Details")
                .font(.appHeadline)
                .foregroundStyle(Color.textPrimaryColor)

            field(title: "List Name", prompt: "e.g., Christmas 2026", text: $name, identifier: "createList.nameField")
            if validity.nameEmptyOrTooLong, !name.isEmpty {
                problemText("Use 1 to \(ListFormValidation.nameLimit) characters.")
            }

            field(
                title: "Theme (Optional)",
                prompt: "e.g., Star Wars, Princess, etc.",
                text: $theme,
                identifier: "createList.themeField"
            )
            if validity.themeTooLong {
                problemText("Use at most \(ListFormValidation.themeLimit) characters.")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .listCard()
    }

    private func field(
        title: String,
        prompt: String,
        text: Binding<String>,
        identifier: String
    ) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(title)
                .font(.appCaption1)
                .foregroundStyle(Color.textMutedColor)
            TextField(prompt, text: text)
                .textFieldStyle(.plain)
                .font(.appBody)
                .foregroundStyle(Color.textPrimaryColor)
                .frame(minHeight: 44)
                .padding(.horizontal, AppSpacing.md)
                .background(Color.backgroundSecondaryColor, in: .rect(cornerRadius: AppSpacing.sm))
                .accessibilityLabel(title)
                .accessibilityIdentifier(identifier)
        }
    }

    private func problemText(_ text: String) -> some View {
        Text(text)
            .font(.appCaption1)
            .foregroundStyle(Color.accentColor)
    }

    private var visibilityCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Visibility")
                .font(.appHeadline)
                .foregroundStyle(Color.textPrimaryColor)

            Picker("Visibility", selection: $visibility) {
                ForEach(ListFormValidation.selectableVisibilities, id: \.self) { option in
                    Label(option.title, systemImage: option.icon)
                        .tag(option)
                }
            }
            .pickerStyle(.menu)
            .frame(minHeight: 44)
            .accessibilityIdentifier("createList.visibilityPicker")

            Text(visibility.summary)
                .font(.appCaption1)
                .foregroundStyle(Color.textMutedColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .listCard()
    }

    private var yearCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Year")
                .font(.appHeadline)
                .foregroundStyle(Color.textPrimaryColor)

            Stepper(value: $year, in: ListFormValidation.yearRange) {
                Text(year.yearDisplay)
                    .font(.appTitle2)
                    .foregroundStyle(Color.textPrimaryColor)
            }
            .accessibilityLabel("Year")
            .accessibilityValue(year.yearDisplay)
            .accessibilityIdentifier("createList.yearStepper")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .listCard()
    }

    // MARK: - Actions

    private func createList() async {
        guard authenticationService.currentUser?.id != nil else { return }
        guard validity.isValid else { return }
        let recipientId = recipientOptions.resolvedSelection(current: selectedRecipientId)

        isCreating = true
        errorBanner = nil
        defer { isCreating = false }

        let input = ListFormValidation.makeCreateInput(
            recipientId: recipientId,
            name: name,
            theme: theme,
            year: year,
            visibility: visibility
        )

        do {
            try await listService.createList(input)
            dismiss()
        } catch is CancellationError {
            return
        } catch {
            errorBanner = MutationBanner.state(for: (error as? ListError) ?? .server)
        }
    }
}

#Preview {
    CreateListView()
        .environment(\.listService, ListService(
            repository: MockListRepository(),
            dataStore: ListDataStore()
        ))
}
