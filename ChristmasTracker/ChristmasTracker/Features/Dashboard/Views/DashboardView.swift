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
    @State private var errorDismissal = ListErrorDismissal()
    @State private var lastOperation = Operation.load

    /// The last operation the dashboard started, so Retry is offered only where it means the same.
    private enum Operation {
        case load
        case refresh
        case archive
        case create
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: AppSpacing.sm) {
                segmentPicker
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
                    begin(.refresh)
                    await listService.refreshLists()
                }
                .sheet(isPresented: $showCreateSheet) {
                    CreateListView()
                }
                .task {
                    if listService.lists.isEmpty {
                        begin(.load)
                        await listService.loadLists()
                    }
                }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if listService.isLoadingLists && listService.lists.isEmpty {
            loadingView
        } else if let error = visibleError, listService.lists.isEmpty {
            ListErrorBanner(
                presentation: ListErrorPresentation(error),
                onRetry: retryAction,
                onDismiss: { errorDismissal.dismiss(error) }
            )
            .padding(EdgeInsets.appScreenPadding)
            .frame(maxHeight: .infinity, alignment: .top)
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

    /// The service error, unless the user dismissed this same error. The service keeps its error
    /// until the next operation, so dismissal is remembered here and reset by every new operation.
    private var visibleError: ListError? {
        errorDismissal.visible(listService.error)
    }

    private func begin(_ operation: Operation) {
        lastOperation = operation
        errorDismissal.reset()
    }

    /// Retry only for a failed load or refresh; a failed delete or create has no meaningful retry here.
    private var retryAction: (() -> Void)? {
        switch lastOperation {
        case .load:
            return {
                begin(.load)
                Task { await listService.loadLists() }
            }
        case .refresh:
            return {
                begin(.refresh)
                Task { await listService.refreshLists() }
            }
        case .archive, .create:
            return nil
        }
    }

    private func openCreate() {
        begin(.create)
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
        begin(.archive)
        Task {
            // A failure is kept by the service as its typed error and shown in the banner.
            try? await listService.deleteList(id: list.id)
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
            if let error = visibleError {
                ListErrorBanner(
                    presentation: ListErrorPresentation(error),
                    onRetry: retryAction,
                    onDismiss: { errorDismissal.dismiss(error) }
                )
                .dashboardRow()
            }
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
