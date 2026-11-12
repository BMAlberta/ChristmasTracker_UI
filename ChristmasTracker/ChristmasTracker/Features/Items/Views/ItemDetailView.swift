//
//  ItemDetailView.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/16/26.
//

import SwiftUI

/// The item detail. Everything shown or enabled comes from `ItemDetailState` (itself derived
/// from the list's capability flags); this view never reads a role or a raw item status. A
/// delete error is held here in local state and shown in an inline banner.
struct ItemDetailView: View {
    let itemId: String
    let context: ItemListContext

    @Environment(\.itemService) private var itemService
    @Environment(\.listService) private var listService
    @Environment(\.authenticationService) private var authenticationService
    @Environment(\.dismiss) private var dismiss

    @State private var sheet: DetailSheet?
    @State private var showDeleteConfirmation = false
    @State private var deleteError: ItemError?
    @State private var hasStartedLoading = false
    @State private var openedPurchase: OpenedPurchase?

    /// The purchase pushed from a row. It carries its own ids so the pushed screen does not depend on
    /// the item staying loaded while this screen is covered.
    private struct OpenedPurchase: Hashable {
        let purchaseId: String
        let itemId: String
        let listId: String
    }

    private enum DetailSheet: Identifiable {
        case edit
        case recordPurchase

        var id: Self { self }
    }

    private var currentItem: ListItem? {
        guard let item = itemService.currentItem, item.id == itemId else { return nil }
        return item
    }

    private func state(for item: ListItem) -> ItemDetailState {
        ItemDetailState(
            item: item,
            context: context,
            currentUserId: authenticationService.currentUser?.id,
            now: .now
        )
    }

    var body: some View {
        content
            .background(Color.backgroundPrimaryColor)
            .navigationTitle("Item Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if let item = currentItem, state(for: item).showsEdit {
                        Button("Edit") {
                            sheet = .edit
                        }
                    }
                }
            }
            .sheet(item: $sheet) { sheet in
                sheetContent(sheet)
            }
            .navigationDestination(item: $openedPurchase) { opened in
                ManagePurchaseView(
                    purchaseId: opened.purchaseId,
                    itemId: opened.itemId,
                    listId: opened.listId,
                    currentUserId: authenticationService.currentUser?.id,
                    onFinish: { finish in
                        handlePurchaseDetailFinish(finish, opened: opened)
                    }
                )
            }
            .onChange(of: itemService.goneItemId) { _, goneId in
                // The server said this item is gone: leave. The service already dropped it.
                if goneId == itemId {
                    dismiss()
                }
            }
            .task {
                hasStartedLoading = true
                await itemService.loadItemDetail(id: itemId)
            }
            .onDisappear {
                // Covered by the purchase detail: keep the item for when this screen comes back.
                guard openedPurchase == nil else { return }
                deleteError = nil
                itemService.clearItemDetail()
                itemService.clearDetailLoadError()
            }
    }

    // MARK: - Content

    private var screenState: ItemDetailScreenState {
        ItemDetailScreenState.resolve(
            item: currentItem,
            isLoading: itemService.isLoadingDetail,
            hasStartedLoading: hasStartedLoading,
            error: itemService.detailLoadError
        )
    }

    @ViewBuilder
    private var content: some View {
        switch screenState {
        case .loaded(let item):
            detailContent(item: item, state: state(for: item))
        case .loading:
            LoadingView(message: "Loading item...")
        case .error(let banner):
            InlineErrorBanner(
                state: banner,
                onTryAgain: { Task { await itemService.loadItemDetail(id: itemId) } },
                onDismiss: { itemService.clearDetailLoadError() }
            )
            .padding(EdgeInsets.appScreenPadding)
            .frame(maxHeight: .infinity, alignment: .top)
        case .notLoaded:
            notLoadedContent
        }
    }

    private var notLoadedContent: some View {
        VStack(spacing: AppSpacing.md) {
            Text(ItemDetailScreenState.notLoadedMessage)
                .font(.appBody)
                .foregroundStyle(Color.textMutedColor)
                .multilineTextAlignment(.center)
            Button("Try Again") {
                Task { await itemService.loadItemDetail(id: itemId) }
            }
            .buttonStyle(.bordered)
            .tint(Color.primaryColor)
            .frame(minHeight: InlineErrorBannerState.minimumButtonHeight)
        }
        .padding(EdgeInsets.appScreenPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func detailContent(item: ListItem, state: ItemDetailState) -> some View {
        ScrollView {
            VStack(spacing: AppSpacing.xl) {
                if let banner = deleteError.flatMap({ ItemErrorPresentation.banner(for: $0, hasRetryAction: true) }) {
                    InlineErrorBanner(
                        state: banner,
                        onTryAgain: { Task { await delete(item) } },
                        onDismiss: { deleteError = nil }
                    )
                }
                headerCard(state: state)
                if state.statusMarker != nil {
                    purchaseStatusCard(item: item, state: state)
                }
                if state.showsPurchaseEntry || state.showsDelete {
                    actionsSection(item: item, state: state)
                }
            }
            .padding(EdgeInsets.appScreenPadding)
        }
    }

    // MARK: - Cards

    private func headerCard(state: ItemDetailState) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text(state.title)
                .font(.appTitle1)
                .foregroundStyle(Color.textPrimaryColor)
            if let description = state.descriptionText {
                Text(description)
                    .font(.appBody)
                    .foregroundStyle(Color.textMutedColor)
            }
            if let price = state.priceText {
                LabeledContent("Expected Price", value: price)
                    .font(.appHeadline)
            }
            LabeledContent("Quantity", value: state.quantityText)
                .font(.appBody)
            LabeledContent("Priority", value: state.priorityText)
                .font(.appBody)
            if let link = state.linkURL {
                Link(destination: link) {
                    Label("View Product", systemImage: "link")
                        .font(.appBody)
                        .frame(minHeight: InlineErrorBannerState.minimumButtonHeight)
                }
            }
            if state.showsOffListBadge {
                Label("Surprise gift - hidden from the recipient", systemImage: "gift.fill")
                    .font(.appCaption1)
                    .foregroundStyle(Color.textPrimaryColor)
                    .padding(.horizontal, AppSpacing.sm)
                    .padding(.vertical, AppSpacing.xs)
                    .background(Color.highlightColor.opacity(0.25), in: .rect(cornerRadius: AppSpacing.xs))
            }
            if let marker = state.statusMarker {
                Label(marker.displayName, systemImage: marker.icon)
                    .font(.appHeadline)
                    .foregroundStyle(marker.tokenColor)
            }
            if let updated = state.updatedText {
                Text(updated)
                    .font(.appCaption1)
                    .foregroundStyle(Color.textMutedColor)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .listCard()
    }

    private func purchaseStatusCard(item: ListItem, state: ItemDetailState) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Purchase Status")
                .font(.appHeadline)
                .foregroundStyle(Color.textPrimaryColor)
            if let progress = state.progress {
                ProgressView(value: progress)
                    .tint(Color.primaryColor)
                    .accessibilityLabel("Purchase progress")
                    .accessibilityValue(Text(progress, format: .percent.precision(.fractionLength(0))))
            }
            if let remaining = state.remainingQuantity {
                Text("\(remaining) remaining")
                    .font(.appBody)
                    .foregroundStyle(Color.textMutedColor)
            }
            ForEach(state.purchases) { purchase in
                ItemPurchaseRow(row: purchase) {
                    openedPurchase = OpenedPurchase(purchaseId: purchase.id, itemId: item.id, listId: item.listId)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .listCard()
    }

    // MARK: - Actions

    private func actionsSection(item: ListItem, state: ItemDetailState) -> some View {
        VStack(spacing: AppSpacing.md) {
            if state.showsPurchaseEntry {
                Button {
                    sheet = .recordPurchase
                } label: {
                    Label("Record Purchase", systemImage: "cart.badge.plus")
                        .font(.appHeadline)
                        .frame(maxWidth: .infinity, minHeight: InlineErrorBannerState.minimumButtonHeight)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.primaryColor)
            }
            if state.showsDelete {
                deleteButton(item: item)
            }
        }
    }

    /// The confirmation dialog is attached to this trigger, not to the screen.
    private func deleteButton(item: ListItem) -> some View {
        Button(role: .destructive) {
            showDeleteConfirmation = true
        } label: {
            Label("Delete Item", systemImage: "trash")
                .font(.appHeadline)
                .frame(maxWidth: .infinity, minHeight: InlineErrorBannerState.minimumButtonHeight)
        }
        .buttonStyle(.bordered)
        .tint(Color.destructiveColor)
        .disabled(itemService.isMutating)
        .confirmationDialog(
            "Delete this item?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Item", role: .destructive) {
                Task { await delete(item) }
            }
            .tint(Color.destructiveColor)
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This action cannot be undone.")
        }
    }

    // MARK: - Sheets

    @ViewBuilder
    private func sheetContent(_ sheet: DetailSheet) -> some View {
        if let item = currentItem {
            switch sheet {
            case .edit:
                EditItemView(item: item)
            case .recordPurchase:
                RecordPurchaseView(item: item, context: context, onFinish: { finish in
                    handleRecordPurchaseFinish(finish, item: item)
                })
            }
        }
    }

    // MARK: - Record purchase

    /// The sheet closes in every case. A recorded purchase refreshes the screens (the server decides
    /// what changed); a 404 means the item is gone, so this screen leaves too.
    private func handleRecordPurchaseFinish(_ finish: RecordPurchaseFinish, item: ListItem) {
        sheet = nil
        switch finish {
        case .recorded:
            Task { await refreshAfterPurchase(item) }
        case .checkItem:
            // The server decides whether the purchase exists: look at the same screens.
            Task { await refreshAfterPurchase(item) }
        case .itemGone:
            dismiss()
        case .cancelled:
            break
        }
    }

    private var refreshRunner: PurchaseRefreshRunner {
        PurchaseRefreshRunner(itemService: itemService, listService: listService)
    }

    /// Runs the refresh plan in order. A failed refresh never turns the recorded purchase into an
    /// error: the screens' own banners apply.
    private func refreshAfterPurchase(_ item: ListItem) async {
        let steps = PurchaseRefreshPlan.steps(
            itemId: item.id, listId: item.listId, currentItemsListId: itemService.currentListId
        )
        await refreshRunner.run(steps)
    }

    // MARK: - Purchase detail

    /// The pushed purchase detail closes in every case. A deleted purchase runs the delete plan; a
    /// purchase that is gone refreshes too (the item may have changed). A failed refresh never turns
    /// the delete into an error.
    private func handlePurchaseDetailFinish(_ finish: PurchaseDetailFinish, opened: OpenedPurchase) {
        openedPurchase = nil
        let steps: [PurchaseRefreshStep]
        switch finish {
        case .deleted:
            steps = PurchaseRefreshPlan.stepsAfterDelete(
                itemId: opened.itemId, listId: opened.listId, currentItemsListId: itemService.currentListId
            )
        case .gone:
            steps = PurchaseRefreshPlan.steps(
                itemId: opened.itemId, listId: opened.listId, currentItemsListId: itemService.currentListId
            )
        }
        Task { await refreshRunner.run(steps) }
    }

    // MARK: - Delete

    private func delete(_ item: ListItem) async {
        deleteError = nil
        do {
            try await itemService.deleteItem(id: item.id, listId: item.listId)
            dismiss()
        } catch is CancellationError {
            // The session ended or the task was cancelled: nothing to show.
        } catch {
            let itemError = (error as? ItemError) ?? ItemError.server
            if ItemErrorPresentation.leavesScreen(itemError) {
                dismiss()
            } else {
                deleteError = itemError
            }
        }
    }
}

#Preview("Owner") {
    NavigationStack {
        ItemDetailView(itemId: "mock-item-child-3", context: ItemListContext(capabilities: MockListData.ownerCapabilities))
            .environment(\.itemService, {
                let service = ItemService(repository: MockItemRepository(), dataStore: ItemDataStore())
                Task { await service.loadItemDetail(id: "mock-item-child-3") }
                return service
            }())
    }
}
