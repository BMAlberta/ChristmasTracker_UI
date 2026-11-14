//
//  DashboardView.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/3/26.
//

import SwiftUI

struct DashboardView: View {
    @Environment(\.listService) private var listService
    @State private var selectedListId: String?
    @State private var showCreateSheet = false
    @State private var listToArchive: GiftList?
    @State private var segment = ListSegment.active
    @State private var searchText = ""
    @State private var dismissed = DismissedLoads()
    @State private var archiveFailure: ListError?
    @State private var archiveRetryListId: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: AppSpacing.sm) {
                segmentPicker
                banners
                content
            }
            .background(Color.backgroundPrimaryColor)
                .navigationTitle("Dashboard")
                .navigationDestination(item: $selectedListId) { listId in
                    ListDetailView(listId: listId)
                }
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        filterMenu
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            openCreate()
                        } label: {
                            Image(systemName: "plus")
                                .frame(minWidth: 44, minHeight: 44)
                        }
                        .accessibilityLabel("New list")
                        .accessibilityIdentifier("dashboard.newListButton")
                    }
                }
                .searchable(text: $searchText, prompt: "Search lists")
                .refreshable {
                    dismissed.reset()
                    await listService.refreshLists()
                }
                .sheet(isPresented: $showCreateSheet) {
                    CreateListView()
                }
                .task {
                    if listService.lists.isEmpty {
                        dismissed.reset()
                        await listService.loadLists()
                    }
                }
                .onDisappear {
                    listService.clearListsLoadFailure()
                    dismissed.reset()
                    archiveFailure = nil
                    archiveRetryListId = nil
                }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if listService.isLoadingLists && listService.lists.isEmpty {
            loadingView
        } else if let fullError = loadPresentation.fullError, listService.lists.isEmpty {
            InlineErrorBanner(
                state: LoadBannerPresentation.state(for: fullError, dismissible: false),
                onTryAgain: { retryLoad() }
            )
            .padding(EdgeInsets.appScreenPadding)
            .frame(maxHeight: .infinity, alignment: .center)
        } else if segmentState.lists.isEmpty {
            emptyStateView
        } else {
            listsView
        }
    }

    /// The lists of the selected segment. The search is applied first, then the segment.
    private var segmentState: ListSegmentState {
        ListSegmentState(segment: segment, lists: searchedLists, isSearching: !searchText.isEmpty)
    }

    private var searchedLists: [GiftList] {
        let filtered = listService.filteredLists
        guard !searchText.isEmpty else { return filtered }
        return filtered.filter { list in
            list.name.localizedCaseInsensitiveContains(searchText) ||
            list.recipientName.localizedCaseInsensitiveContains(searchText) ||
            (list.theme?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    /// What the lists load failure shows: the pure state decides, the view renders it.
    private var loadPresentation: ScreenLoadPresentation {
        DashboardLoadState.make(
            hasCachedLists: !listService.lists.isEmpty,
            listsFailure: listService.listsLoadFailure,
            archiveFailure: archiveFailure,
            dismissed: dismissed
        )
    }

    /// The load banners and the archive failure, above the lists.
    @ViewBuilder
    private var banners: some View {
        let loadBanners = loadPresentation.banners
        let archiveBanner = archiveFailure.flatMap { MutationBanner.state(for: $0) }
        if !loadBanners.isEmpty || archiveBanner != nil {
            VStack(spacing: AppSpacing.sm) {
                ForEach(Array(loadBanners.enumerated()), id: \.offset) { _, banner in
                    InlineErrorBanner(
                        state: LoadBannerPresentation.state(for: banner),
                        onTryAgain: { retryLoad() },
                        onDismiss: { dismissed.dismiss(banner.retryTargets) }
                    )
                }
                if let archiveBanner {
                    InlineErrorBanner(
                        state: archiveBanner,
                        onTryAgain: { retryArchive() },
                        onDismiss: { clearArchiveFailure() }
                    )
                }
            }
            .padding(.horizontal, AppSpacing.lg)
        }
    }

    /// Try Again repeats the lists load as a forced fetch.
    private func retryLoad() {
        dismissed.reset()
        Task { await listService.refreshLists() }
    }

    private func clearArchiveFailure() {
        archiveFailure = nil
        archiveRetryListId = nil
    }

    private func openCreate() {
        showCreateSheet = true
    }

    /// True while the archive confirmation of this very row is shown.
    private func archiveDialogBinding(for list: GiftList) -> Binding<Bool> {
        Binding(
            get: { listToArchive?.id == list.id },
            set: { isPresented in
                if !isPresented, listToArchive?.id == list.id { listToArchive = nil }
            }
        )
    }

    private func confirmArchive() {
        guard let list = listToArchive else { return }
        listToArchive = nil
        archive(listId: list.id)
    }

    private func retryArchive() {
        guard let listId = archiveRetryListId else { return }
        archive(listId: listId)
    }

    private func archive(listId: String) {
        clearArchiveFailure()
        Task {
            // The service throws the failure; the dashboard keeps it in local state for the banner.
            do {
                try await listService.deleteList(id: listId)
            } catch is CancellationError {
                return
            } catch let failure as ListError {
                archiveFailure = failure
                archiveRetryListId = listId
            } catch {
                archiveFailure = .server
                archiveRetryListId = listId
            }
        }
    }

    // MARK: - Subviews

    private var segmentPicker: some View {
        Picker("Lists", selection: $segment) {
            ForEach(ListSegment.allCases, id: \.self) { segment in
                Text(segment.title).tag(segment)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, AppSpacing.lg)
        .accessibilityIdentifier("dashboard.segmentPicker")
    }

    private var filterMenu: some View {
        let binding = Binding(
            get: { listService.currentFilter },
            set: { listService.currentFilter = $0 }
        )

        return Menu {
            Picker("Filter", selection: binding) {
                Label("All Lists", systemImage: "list.bullet")
                    .tag(ListService.FilterType.all)

                Label("My Lists", systemImage: "person.fill")
                    .tag(ListService.FilterType.owned)

                Label("Shared With Me", systemImage: "person.2.fill")
                    .tag(ListService.FilterType.shared)
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } label: {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .frame(minWidth: 44, minHeight: 44)
        }
        .accessibilityLabel("Filter lists")
    }

    private var loadingView: some View {
        ScrollView {
            LazyVStack(spacing: AppSpacing.lg) {
                ForEach(0..<3, id: \.self) { _ in
                    SkeletonListCard()
                }
            }
            .padding(EdgeInsets.appScreenPadding)
        }
    }

    @ViewBuilder
    private var emptyStateView: some View {
        let state = segmentState
        if searchText.isEmpty {
            if state.showsCreateAction {
                EmptyStateView(
                    icon: "gift.fill",
                    title: state.emptyTitle,
                    message: state.emptyMessage,
                    actionTitle: "Create List"
                ) {
                    openCreate()
                }
            } else {
                EmptyStateView(icon: "archivebox", title: state.emptyTitle, message: state.emptyMessage)
            }
        } else {
            EmptyStateView(icon: "magnifyingglass", title: state.emptyTitle, message: state.emptyMessage)
        }
    }

    private var listsView: some View {
        List {
            if let lastUpdated = listService.lastUpdated {
                lastUpdatedView(date: lastUpdated)
                    .dashboardRow()
            }
            ForEach(segmentState.lists) { list in
                row(for: list)
                    .dashboardRow()
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func row(for list: GiftList) -> some View {
        let state = ListRowState(list: list)
        return Button {
            selectedListId = list.id
        } label: {
            rowLabel(state: state)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("dashboard.listRow")
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if state.showsDeleteAction {
                Button(role: .destructive) {
                    listToArchive = list
                } label: {
                    Label("Archive", systemImage: "archivebox")
                }
            }
        }
        // Attached to the row's own trigger, not to the stack or the list.
        .confirmationDialog(
            ListArchiveConfirmation.title,
            isPresented: archiveDialogBinding(for: list),
            titleVisibility: .visible
        ) {
            Button(ListArchiveConfirmation.confirmButtonTitle, role: .destructive) {
                confirmArchive()
            }
            Button("Cancel", role: .cancel) {
                listToArchive = nil
            }
        } message: {
            Text(ListArchiveConfirmation.message)
        }
    }

    private func rowLabel(state: ListRowState) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            if state.showsArchivedBadge {
                // The row's accessibility label already says Archived.
                ListArchivedBadgeView()
                    .accessibilityHidden(true)
            }
            ListPreviewCard(state: state)
        }
    }

    private func lastUpdatedView(date: Date) -> some View {
        HStack {
            Image(systemName: "clock.arrow.circlepath")
                .font(.appCaption2)
                .foregroundStyle(Color.textMutedColor)
            Text("Updated \(date.timeAgoDisplay)")
                .font(.appCaption2)
                .foregroundStyle(Color.textMutedColor)
            Spacer()
        }
    }
}

private extension View {
    /// Plain, card-like rows on the screen background.
    func dashboardRow() -> some View {
        self
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(
                top: AppSpacing.sm,
                leading: AppSpacing.lg,
                bottom: AppSpacing.sm,
                trailing: AppSpacing.lg
            ))
    }
}

#Preview("With Lists") {
    DashboardView()
        .environment(\.listService, ListService(
            repository: MockListRepository(),
            dataStore: ListDataStore()
        ))
}

#Preview("With an archived list") {
    DashboardView()
        .environment(\.listService, ListService(
            repository: MockListRepository(includeAllScenarios: true),
            dataStore: ListDataStore()
        ))
}

#Preview("Empty") {
    DashboardView()
        .environment(\.listService, ListService(
            repository: MockListRepository(withMockData: false),
            dataStore: ListDataStore()
        ))
}
