//
//  ListDetailView.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/13/26.
//

import SwiftUI

struct ListDetailView: View {
    let listId: String
    @Environment(\.listService) private var listService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.itemService) private var itemService
    @Environment(\.authenticationService) private var authenticationService

    @State private var editingDetail: ListDetail?
    @State private var showArchiveConfirmation = false
    @State private var selectedItemId: String?
    @State private var actionError: ListErrorPresentation?
    @State private var failedAction: FailedAction?
    @State private var showsAddMember = false
    @State private var memberToRemove: MemberRowState?
    @State private var showLeaveConfirmation = false
    @State private var showsAddItem = false
    @State private var refreshError: ListError?

    /// The action whose failure is shown in the banner, so Try Again repeats that action.
    private enum FailedAction {
        case archiveList
        case leaveList
        case removeMember(MemberRowState)
    }

    /// The loaded detail, only when it belongs to this screen's list. A previous list's data
    /// is never shown while this list loads.
    private var currentDetail: ListDetail? {
        guard let detail = listService.currentListDetail, detail.id == listId else { return nil }
        return detail
    }

    var body: some View {
        let detail = currentDetail
        let state = detail.map { ListDetailState(detail: $0) }
        return content(detail: detail, state: state)
            .background(Color.backgroundPrimaryColor)
            .navigationTitle("List Details")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(item: $selectedItemId) { itemId in
                if let detail {
                    ItemDetailView(itemId: itemId, context: ItemListContext(detail: detail))
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if let detail, state?.showsEditAction == true {
                        Button("Edit") {
                            editingDetail = detail
                        }
                        .frame(minHeight: 44)
                        .accessibilityHint("Changes the name, theme and visibility of this list")
                        .accessibilityIdentifier("listDetail.editButton")
                    }
                }
            }
            .sheet(item: $editingDetail) { detail in
                EditListView(list: detail)
            }
            .sheet(isPresented: $showsAddMember) {
                AddMemberView(listId: listId)
            }
            .sheet(isPresented: $showsAddItem) {
                if let detail {
                    AddItemView(listId: listId, context: ItemListContext(detail: detail))
                }
            }
            .confirmationDialog(
                MembersSectionState.leaveConfirmation.title,
                isPresented: $showLeaveConfirmation,
                titleVisibility: .visible
            ) {
                Button(MembersSectionState.leaveConfirmation.confirmButtonTitle, role: .destructive) {
                    Task { await leaveList() }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text(MembersSectionState.leaveConfirmation.message)
            }
            .confirmationDialog(
                memberToRemove.map { MembersSectionState.removeConfirmation(for: $0).title } ?? "",
                isPresented: Binding(
                    get: { memberToRemove != nil },
                    set: { if !$0 { memberToRemove = nil } }
                ),
                titleVisibility: .visible,
                presenting: memberToRemove
            ) { row in
                Button(MembersSectionState.removeConfirmation(for: row).confirmButtonTitle, role: .destructive) {
                    Task { await removeMember(row) }
                }
                Button("Cancel", role: .cancel) { }
            } message: { row in
                Text(MembersSectionState.removeConfirmation(for: row).message)
            }
            .onChange(of: listService.goneListId) { _, goneId in
                // This list is gone: leave. The service has already dropped it.
                if ListScreenExit.shouldDismissDetail(goneListId: goneId, openListId: listId) {
                    dismiss()
                }
            }
            .refreshable {
                await refresh()
            }
            .task {
                await load()
            }
            .onDisappear {
                refreshError = nil
                itemService.clearListLoadError()
            }
    }

    // MARK: - Content

    @ViewBuilder
    private func content(detail: ListDetail?, state: ListDetailState?) -> some View {
        if let detail, let state {
            detailContent(detail: detail, state: state)
        } else if !listService.isLoadingDetail, let error = listService.error {
            ListErrorBanner(
                presentation: ListErrorPresentation(error),
                onRetry: { Task { await load() } },
                onLeave: { dismiss() }
            )
            .padding(EdgeInsets.appScreenPadding)
            .frame(maxHeight: .infinity, alignment: .top)
        } else {
            LoadingView(message: "Loading list...")
        }
    }

    private func load() async {
        actionError = nil
        await listService.loadListDetail(id: listId)
        await itemService.loadItems(listId: listId)
    }

    /// Pull to refresh: always fetches the detail and the items, and reports a detail failure.
    private func refresh() async {
        refreshError = nil
        refreshError = await listService.refreshListDetail(id: listId)
        switch ListDetailRefresh.itemsStep(currentItemsListId: itemService.currentListId, listId: listId) {
        case .refresh: await itemService.refreshItems()
        case .load: await itemService.loadItems(listId: listId)
        }
    }

    private func archiveList() async {
        actionError = nil
        do {
            try await listService.deleteList(id: listId)
            // A failed reload still archived the list but leaves the error for the screen to show.
            switch ListArchiveCompletion.after(serviceError: listService.error) {
            case .dismiss:
                dismiss()
            case .showError(let presentation):
                // No retry: repeating the action would archive again.
                failedAction = nil
                actionError = presentation
            }
        } catch is CancellationError {
            return
        } catch {
            failedAction = .archiveList
            actionError = ListErrorPresentation((error as? ListError) ?? .server)
        }
    }

    private func removeMember(_ row: MemberRowState) async {
        actionError = nil
        do {
            try await listService.removeMember(listId: listId, userId: row.userId)
        } catch is CancellationError {
            return
        } catch {
            failedAction = .removeMember(row)
            actionError = ListErrorPresentation((error as? ListError) ?? .server)
        }
    }

    /// Leaves the list as the signed-in user. The detail screen pops when the service reports
    /// the list gone.
    private func leaveList() async {
        actionError = nil
        guard let userId = authenticationService.currentUser?.id else {
            failedAction = nil
            actionError = ListErrorPresentation(.sessionEnded)
            return
        }
        do {
            try await listService.leaveList(id: listId, userId: userId)
        } catch is CancellationError {
            return
        } catch {
            failedAction = .leaveList
            actionError = ListErrorPresentation((error as? ListError) ?? .server)
        }
    }

    private func retryFailedAction() async {
        switch failedAction {
        case .archiveList: await archiveList()
        case .leaveList: await leaveList()
        case .removeMember(let row): await removeMember(row)
        case nil: break
        }
    }

    private func detailContent(detail: ListDetail, state: ListDetailState) -> some View {
        ScrollView {
            VStack(spacing: AppSpacing.xl) {
                if let refreshBanner = ListDetailRefresh.banner(for: refreshError) {
                    InlineErrorBanner(
                        state: refreshBanner,
                        onTryAgain: { Task { await refresh() } },
                        onDismiss: { refreshError = nil }
                    )
                }
                if let actionError {
                    ListErrorBanner(
                        presentation: actionError,
                        onRetry: failedAction == nil ? nil : { Task { await retryFailedAction() } },
                        onLeave: { dismiss() },
                        onDismiss: { self.actionError = nil }
                    )
                }
                headerCard(state: state)
                if state.showsStatsCard,
                   let itemCountText = state.itemCountText,
                   let purchasedCountText = state.purchasedCountText {
                    statsCard(
                        itemCountText: itemCountText,
                        purchasedCountText: purchasedCountText,
                        progress: state.progress
                    )
                }
                itemsSection(detail: detail)
                membersSection(detail: detail)
                if state.showsDeleteAction {
                    archiveButton
                }
            }
            .padding(EdgeInsets.appScreenPadding)
        }
    }

    /// Items render only under the list they were loaded for.
    private var scopedItems: [ListItem] {
        ListItemsScope.itemsToShow(itemService.items, currentListId: itemService.currentListId, listId: listId)
    }

    // MARK: - Cards

    private func headerCard(state: ListDetailState) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(alignment: .top, spacing: AppSpacing.md) {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(state.title)
                        .font(.appTitle1)
                        .foregroundStyle(Color.textPrimaryColor)
                    Text(state.subtitle)
                        .font(.appTitle3)
                        .foregroundStyle(Color.textMutedColor)
                }
                Spacer(minLength: AppSpacing.sm)
                VStack(alignment: .trailing, spacing: AppSpacing.xs) {
                    ListBadge(title: state.badgeTitle, tone: state.badgeTone)
                    if state.showsArchivedBadge {
                        ListArchivedBadgeView()
                    }
                }
            }
            if let theme = state.theme, !theme.isEmpty {
                Label(theme, systemImage: "sparkles")
                    .font(.appBody)
                    .foregroundStyle(Color.accentColor)
            }
            HStack {
                Label(state.year.yearDisplay, systemImage: "calendar")
                Spacer()
                Label(state.visibilityTitle, systemImage: state.visibilityIcon)
            }
            .font(.appCaption1)
            .foregroundStyle(Color.textMutedColor)
            Label(state.memberCountText, systemImage: "person.2")
                .font(.appCaption1)
                .foregroundStyle(Color.textMutedColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .listCard()
    }

    private func statsCard(itemCountText: String, purchasedCountText: String, progress: Double?) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Progress")
                .font(.appHeadline)
                .foregroundStyle(Color.textPrimaryColor)
            ListCountsView(
                itemCountText: itemCountText,
                purchasedCountText: purchasedCountText,
                progress: progress
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .listCard()
    }

    private func membersSection(detail: ListDetail) -> some View {
        MembersSectionView(
            state: MembersSectionState(detail: detail),
            isMutating: listService.isMutating,
            onAdd: { showsAddMember = true },
            onRemove: { memberToRemove = $0 },
            onLeave: { showLeaveConfirmation = true }
        )
    }

    /// The confirmation dialog is attached to this trigger, not to the screen.
    private var archiveButton: some View {
        Button(role: .destructive) {
            showArchiveConfirmation = true
        } label: {
            Label(ListArchiveConfirmation.actionTitle, systemImage: "archivebox")
                .font(.appHeadline)
                .foregroundStyle(Color.surfaceColor)
                .frame(maxWidth: .infinity, minHeight: 44)
                .padding(.vertical, AppSpacing.xs)
                .background(Color.accentColor, in: .rect(cornerRadius: AppSpacing.md))
        }
        .disabled(listService.isMutating)
        .accessibilityHint("Moves this list to Archived after you confirm")
        .accessibilityIdentifier("listDetail.archiveButton")
        .confirmationDialog(
            ListArchiveConfirmation.title,
            isPresented: $showArchiveConfirmation,
            titleVisibility: .visible
        ) {
            Button(ListArchiveConfirmation.confirmButtonTitle, role: .destructive) {
                Task { await archiveList() }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(ListArchiveConfirmation.message)
        }
    }

    /// The items, driven by `ItemListState` (flags through ItemPermissions). The load error is the
    /// item service's separate `listLoadError`; Try Again refreshes, and it clears when this screen
    /// disappears.
    private func itemsSection(detail: ListDetail) -> some View {
        let listState = ItemListState(
            items: scopedItems,
            context: ItemListContext(detail: detail),
            currentUserId: authenticationService.currentUser?.id
        )
        let banner = itemService.listLoadError.flatMap {
            ItemErrorPresentation.banner(for: $0, hasRetryAction: true)
        }
        return ItemsSectionView(
            state: listState,
            isLoading: itemService.isLoadingItems,
            errorBanner: banner,
            onSelect: { selectedItemId = $0 },
            onAdd: { showsAddItem = true },
            onTryAgain: { Task { await itemService.refreshItems() } },
            onDismissError: { itemService.clearListLoadError() }
        )
        .listCard()
    }
}

#Preview("Owner of a child list") {
    NavigationStack {
        ListDetailView(listId: MockListData.ownerOfChildList.id)
            .environment(\.listService, ListService(
                repository: MockListRepository(),
                dataStore: ListDataStore()
            ))
    }
}

#Preview("Archived list") {
    NavigationStack {
        ListDetailView(listId: MockListData.archivedList.id)
            .environment(\.listService, ListService(
                repository: MockListRepository(includeAllScenarios: true),
                dataStore: ListDataStore()
            ))
    }
}

#Preview("Owner of a self list") {
    NavigationStack {
        ListDetailView(listId: MockListData.blindOwnerOfSelfList.id)
            .environment(\.listService, ListService(
                repository: MockListRepository(),
                dataStore: ListDataStore()
            ))
    }
}
