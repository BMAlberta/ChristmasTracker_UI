//
//  ManagePurchaseView.swift
//  ChristmasTracker
//
//  The purchase detail of a purchase the signed-in user made: the read-only core rows, a Shipping
//  section, a Notes section and a Delete button. Everything shown comes from PurchaseDetailModel;
//  this view renders state and sends events only. Each section owns its own error banner, and the
//  load banner sits at the top. The view reports the end of the screen once through `onFinish`; the
//  host closes it and, after a delete, runs the refresh plan.
//

import SwiftUI

struct ManagePurchaseView: View {
    let purchaseId: String
    let itemId: String
    let listId: String
    let currentUserId: String?
    let onFinish: (PurchaseDetailFinish) -> Void

    @Environment(\.purchaseService) private var purchaseService

    // The environment service is not readable in init, so the model is built once, in `.task`,
    // never in `body`. Until then a progress view shows.
    @State private var model: PurchaseDetailModel?

    var body: some View {
        if let model {
            ManagePurchaseContent(model: model, onFinish: onFinish)
        } else {
            ProgressView("Loading purchase...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .task { buildModelOnce() }
        }
    }

    private func buildModelOnce() {
        guard model == nil else { return }
        model = PurchaseDetailModel(
            purchaseId: purchaseId,
            itemId: itemId,
            listId: listId,
            currentUserId: currentUserId,
            service: purchaseService
        )
    }
}

struct ManagePurchaseContent: View {
    let onFinish: (PurchaseDetailFinish) -> Void

    @State private var model: PurchaseDetailModel

    init(model: PurchaseDetailModel, onFinish: @escaping (PurchaseDetailFinish) -> Void) {
        self.onFinish = onFinish
        _model = State(initialValue: model)
    }

    var body: some View {
        Form {
            if let banner = model.loadBanner {
                Section {
                    InlineErrorBanner(
                        state: banner,
                        onTryAgain: { Task { await model.retryLoad() } },
                        onDismiss: { model.dismissLoadError() }
                    )
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
            }
            sections
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Your Purchase")
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load() }
        .onChange(of: model.finish) { _, finish in
            if let finish { onFinish(finish) }
        }
        .onChange(of: model.announcementCount) { postAnnouncement() }
        .onDisappear { model.disappear() }
    }

    @ViewBuilder
    private var sections: some View {
        switch model.phase {
        case .loading:
            Section {
                ProgressView("Loading purchase...")
                    .frame(maxWidth: .infinity, minHeight: InlineErrorBannerState.minimumButtonHeight)
            }
        case .loaded(let state):
            ManagePurchaseCoreSection(state: state)
            ManagePurchaseShippingSection(model: model)
            ManagePurchaseNotesSection(model: model)
            ManagePurchaseDeleteSection(model: model)
        case .failed:
            EmptyView()
        }
    }

    /// Error texts are announced by their banner; only results are announced here.
    private func postAnnouncement() {
        guard !model.announcementIsError, let text = model.announcement else { return }
        AccessibilityNotification.Announcement(text).post()
    }
}

// MARK: - Core rows

struct ManagePurchaseCoreSection: View {
    let state: PurchaseDetailState

    var body: some View {
        Section {
            LabeledContent("Item", value: state.itemName)
            Text(state.quantityText)
            LabeledContent("Total cost", value: state.totalCostText)
            if let store = state.storeText {
                LabeledContent("Store", value: store)
            }
            LabeledContent("Purchased", value: state.purchasedText)
            if let confirmation = state.confirmationNumberText {
                LabeledContent("Confirmation number", value: confirmation)
            }
            Text(PurchaseDetailState.immutableSentence)
                .font(.appCaption1)
                .foregroundStyle(Color.textMutedColor)
        }
        .font(.appBody)
        .foregroundStyle(Color.textPrimaryColor)
    }
}

// MARK: - Shipping

struct ManagePurchaseShippingSection: View {
    let model: PurchaseDetailModel

    private var statusBinding: Binding<PurchaseShippingStatus> {
        Binding(
            get: { model.shipping?.draftStatus ?? .notTracked },
            set: { model.editShipping(status: $0, tracking: model.shipping?.draftTracking ?? "") }
        )
    }

    private var trackingBinding: Binding<String> {
        Binding(
            get: { model.shipping?.draftTracking ?? "" },
            set: { model.editShipping(status: model.shipping?.draftStatus ?? .notTracked, tracking: $0) }
        )
    }

    var body: some View {
        Section {
            if let banner = model.shippingBanner {
                InlineErrorBanner(
                    state: banner,
                    onTryAgain: { Task { await model.saveShipping() } },
                    onDismiss: { model.dismissShippingError() }
                )
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
            Picker("Status", selection: statusBinding) {
                ForEach(PurchaseShippingStatus.allCases, id: \.self) { status in
                    Text(status.displayName).tag(status)
                }
            }
            .font(.appBody)
            .disabled(model.isSavingShipping)
            TextField("Tracking number", text: trackingBinding)
                .font(.appBody)
                .autocorrectionDisabled()
                .disabled(model.isSavingShipping)
                .accessibilityLabel("Tracking number")
            if model.shipping?.trackingTooLong == true {
                Text("The tracking number is too long.")
                    .font(.appCaption1)
                    .foregroundStyle(Color.destructiveColor)
            }
            saveButton
        } header: {
            Text("Shipping")
        }
    }

    private var saveButton: some View {
        Button {
            Task { await model.saveShipping() }
        } label: {
            HStack {
                if model.isSavingShipping {
                    ProgressView()
                }
                Text("Save Shipping")
                    .font(.appHeadline)
            }
            .frame(maxWidth: .infinity, minHeight: InlineErrorBannerState.minimumButtonHeight)
        }
        .buttonStyle(.borderedProminent)
        .tint(Color.primaryColor)
        .disabled(model.shipping?.canSave != true || model.isSavingShipping)
        .accessibilityHint("Saves the shipping status and tracking number")
    }
}

// MARK: - Notes

struct ManagePurchaseNotesSection: View {
    let model: PurchaseDetailModel

    private var notesBinding: Binding<String> {
        Binding(
            get: { model.notes?.draftText ?? "" },
            set: { model.editNotes(text: $0) }
        )
    }

    var body: some View {
        Section {
            if let banner = model.notesBanner {
                InlineErrorBanner(
                    state: banner,
                    onTryAgain: { Task { await model.saveNotes() } },
                    onDismiss: { model.dismissNotesError() }
                )
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                TextField("Notes", text: notesBinding, axis: .vertical)
                    .font(.appBody)
                    .lineLimit(3...8)
                    .disabled(model.isSavingNotes)
                    .accessibilityLabel("Notes")
                if let remaining = model.notes?.remainingCharacters {
                    Text("\(remaining) characters left")
                        .font(.appCaption1)
                        .foregroundStyle(remaining < 0 ? Color.destructiveColor : Color.textMutedColor)
                        .accessibilityLabel("\(remaining) characters left in the notes")
                }
            }
            saveButton
        } header: {
            Text("Notes")
        }
    }

    private var saveButton: some View {
        Button {
            Task { await model.saveNotes() }
        } label: {
            HStack {
                if model.isSavingNotes {
                    ProgressView()
                }
                Text("Save Notes")
                    .font(.appHeadline)
            }
            .frame(maxWidth: .infinity, minHeight: InlineErrorBannerState.minimumButtonHeight)
        }
        .buttonStyle(.borderedProminent)
        .tint(Color.primaryColor)
        .disabled(model.notes?.canSave != true || model.isSavingNotes)
        .accessibilityHint("Saves the notes")
    }
}

// MARK: - Delete

struct ManagePurchaseDeleteSection: View {
    let model: PurchaseDetailModel

    @State private var isShowingDeleteConfirmation = false

    var body: some View {
        Section {
            if let banner = model.deleteBanner {
                InlineErrorBanner(
                    state: banner,
                    onTryAgain: { Task { await model.confirmDelete() } },
                    onDismiss: { model.dismissDeleteError() }
                )
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
            deleteButton
        }
    }

    /// The one confirmation dialog of this screen is attached to this trigger, not to the form.
    private var deleteButton: some View {
        Button(role: .destructive) {
            isShowingDeleteConfirmation = true
        } label: {
            HStack {
                if model.isDeleting {
                    ProgressView()
                }
                Label(PurchaseDetailState.deleteButtonTitle, systemImage: "trash")
                    .font(.appHeadline)
            }
            .frame(maxWidth: .infinity, minHeight: InlineErrorBannerState.minimumButtonHeight)
        }
        .buttonStyle(.bordered)
        .tint(Color.destructiveColor)
        .disabled(model.isDeleting)
        .accessibilityHint("Asks you to confirm before deleting")
        .confirmationDialog(
            PurchaseDetailState.deleteTitle,
            isPresented: $isShowingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(PurchaseDetailState.deleteButtonTitle, role: .destructive) {
                Task { await model.confirmDelete() }
            }
            .tint(Color.destructiveColor)
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(PurchaseDetailState.deleteMessage)
        }
    }
}
