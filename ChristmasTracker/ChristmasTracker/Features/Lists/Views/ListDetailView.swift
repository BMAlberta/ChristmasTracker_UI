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

    @State private var editingDetail: ListDetail?
    @State private var showDeleteConfirmation = false
    @State private var selectedItemId: String?
    @State private var actionError: ListErrorPresentation?

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
                ItemDetailView(itemId: itemId)
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
            .confirmationDialog(
                ListDeleteConfirmation.title,
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button(ListDeleteConfirmation.confirmButtonTitle, role: .destructive) {
                    Task { await deleteList() }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text(ListDeleteConfirmation.message)
            }
            .refreshable {
                await load()
            }
            .task {
                await load()
            }
    }

    // MARK: - Content

    @ViewBuilder
    private func content(detail: ListDetail?, state: ListDetailState?) -> some View {
        if let detail, let state {
            detailContent(detail: detail, state: state)
        } else if !listService.isLoading, let error = listService.error {
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

    private func deleteList() async {
        do {
            try await listService.deleteList(id: listId)
            dismiss()
        } catch is CancellationError {
            return
        } catch {
            actionError = ListErrorPresentation((error as? ListError) ?? .server)
        }
    }

    private func detailContent(detail: ListDetail, state: ListDetailState) -> some View {
        ScrollView {
            VStack(spacing: AppSpacing.xl) {
                if let actionError {
                    ListErrorBanner(
                        presentation: actionError,
                        onRetry: { Task { await deleteList() } },
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
                if showsItemsSection(state: state) {
                    itemsSection(state: state, detail: detail)
                }
                if state.showsMembersSection, let members = detail.members {
                    membersCard(members: members)
                }
                if state.showsDeleteAction {
                    deleteButton
                }
            }
            .padding(EdgeInsets.appScreenPadding)
        }
    }

    /// Viewers who may not see counts get no items section unless items were actually returned,
    /// so an empty section never hints at whether items exist.
    private func showsItemsSection(state: ListDetailState) -> Bool {
        state.showsStatsCard || !scopedItems.isEmpty
    }

    /// Items render only under the list they were loaded for.
    private var scopedItems: [GiftItem] {
        ListItemsScope.itemsToShow(itemService.items, currentListId: itemService.currentListId, listId: listId)
    }

    private var scopedFilteredItems: [GiftItem] {
        ListItemsScope.itemsToShow(
            itemService.filteredItems,
            currentListId: itemService.currentListId,
            listId: listId
        )
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
                ListBadge(title: state.badgeTitle, tone: state.badgeTone)
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

    private func membersCard(members: [ListMember]) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack {
                Text("Members")
                    .font(.appHeadline)
                    .foregroundStyle(Color.textPrimaryColor)
                Spacer()
                Text("\(members.count)")
                    .font(.appCaption1)
                    .foregroundStyle(Color.textMutedColor)
            }
            ForEach(members) { member in
                HStack(spacing: AppSpacing.md) {
                    Circle()
                        .fill(Color.primaryColor.opacity(0.2))
                        .frame(width: 44, height: 44)
                        .overlay {
                            Text(String(member.displayName.prefix(1)))
                                .font(.appHeadline)
                                .foregroundStyle(Color.primaryColor)
                        }
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text(member.displayName)
                            .font(.appBody)
                            .foregroundStyle(Color.textPrimaryColor)
                        if let email = member.email {
                            Text(email)
                                .font(.appCaption1)
                                .foregroundStyle(Color.textMutedColor)
                        }
                    }
                    Spacer()
                    Text(member.role.displayName)
                        .font(.appCaption1)
                        .foregroundStyle(Color.textMutedColor)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .listCard()
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            showDeleteConfirmation = true
        } label: {
            Label("Delete List", systemImage: "trash")
                .font(.appHeadline)
                .foregroundStyle(Color.surfaceColor)
                .frame(maxWidth: .infinity, minHeight: 44)
                .padding(.vertical, AppSpacing.xs)
                .background(Color.accentColor, in: .rect(cornerRadius: AppSpacing.md))
        }
        .accessibilityHint("Removes this list from your lists after you confirm")
        .accessibilityIdentifier("listDetail.deleteButton")
    }

    private func itemsSection(state: ListDetailState, detail: ListDetail) -> some View {
        let items = scopedFilteredItems
        let hasItems = !scopedItems.isEmpty
        let firstItemId = items.first?.id
        return VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack {
                Text("Items")
                    .font(.appHeadline)
                    .foregroundStyle(Color.textPrimaryColor)
                Spacer()
                if state.showsStatsCard, hasItems {
                    Text("\(items.count)")
                        .font(.appCaption1)
                        .foregroundStyle(Color.textMutedColor)
                }
            }
            if itemService.isLoading && !hasItems {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.xl)
            } else if !hasItems {
                VStack(spacing: AppSpacing.md) {
                    Image(systemName: "gift.fill")
                        .font(.appTitle1)
                        .foregroundStyle(Color.textMutedColor)
                        .accessibilityHidden(true)
                    Text("No items yet")
                        .font(.appBody)
                        .foregroundStyle(Color.textMutedColor)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.xl)
            } else {
                ForEach(items) { item in
                    Button {
                        selectedItemId = item.id
                    } label: {
                        ItemRow(item: item, detail: detail)
                            .frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .overlay(alignment: .top) {
                        if item.id != firstItemId {
                            Divider()
                                .padding(.leading, AppSpacing.xxxl)
                                .offset(y: -AppSpacing.md / 2)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

#Preview("Blind owner") {
    NavigationStack {
        ListDetailView(listId: MockListData.blindOwnerOfSelfList.id)
            .environment(\.listService, ListService(
                repository: MockListRepository(),
                dataStore: ListDataStore()
            ))
    }
}
