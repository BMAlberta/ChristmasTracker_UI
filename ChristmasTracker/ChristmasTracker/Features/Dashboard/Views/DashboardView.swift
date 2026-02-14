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
    @State private var listToDelete: GiftList?
    @State private var searchText = ""
    var body: some View {
        NavigationStack {
            Group {
                if listService.isLoading && listService.lists.isEmpty {
                    loadingView
                } else if let error = listService.error, listService.lists.isEmpty {
                    ErrorStateView(error: error) {
                        Task { await listService.loadLists() }
                    }
                } else if displayedLists.isEmpty {
                    emptyStateView
                } else {
                    listsScrollView
                }
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
                        showCreateSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search lists")
            .refreshable {
                await listService.refreshLists()
            }
            .sheet(isPresented: $showCreateSheet) {
                CreateListView()
            }
            .confirmationDialog(
                "Delete List",
                isPresented: .constant(listToDelete != nil),
                presenting: listToDelete
            ) { list in
                Button("Delete '\(list.name)'", role: .destructive) {
                    Task {
                        do {
                            try await listService.deleteList(id: list.id)
                            listToDelete = nil
                        } catch {
                            listToDelete = nil
                        }
                    }
                }
                Button("Cancel", role: .cancel) {
                    listToDelete = nil
                }
            } message: { list in
                Text("This will permanently delete '\(list.name)' and all its items.")
            }
            .task {
                if listService.lists.isEmpty {
                    await listService.loadLists()
                }
            }
        }
    }
    // MARK: - Computed Properties
    private var displayedLists: [GiftList] {
        let filtered = listService.filteredLists
        if searchText.isEmpty {
            return filtered
        } else {
            return filtered.filter { list in
                list.name.localizedCaseInsensitiveContains(searchText) ||
                list.recipientName.localizedCaseInsensitiveContains(searchText) ||
                (list.theme?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
    }
    // MARK: - Subviews
    private var filterMenu: some View {
        // Create local state that tracks service state
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
        }
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
    private var emptyStateView: some View {
        Group {
            if searchText.isEmpty {
                EmptyStateView(
                    icon: "gift.fill",
                    title: "No Lists Yet",
                    message: "Create your first gift list to get started",
                    actionTitle: "Create List"
                ) {
                    showCreateSheet = true
                }
            } else {
                EmptyStateView(
                    icon: "magnifyingglass",
                    title: "No Results",
                    message: "No lists match '\(searchText)'"
                )
            }
        }
    }
    private var listsScrollView: some View {
        ScrollView {
            LazyVStack(spacing: AppSpacing.lg) {
                if let lastUpdated = listService.lastUpdated {
                    lastUpdatedView(date: lastUpdated)
                }
                ForEach(displayedLists) { list in
                    ListPreviewCard(list: list)
                        .onTapGesture {
                            selectedListId = list.id
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if list.myRole == .owner {
                                Button(role: .destructive) {
                                    listToDelete = list
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                }
            }
            .padding(EdgeInsets.appScreenPadding)
        }
    }
    private func lastUpdatedView(date: Date) -> some View {
        HStack {
            Image(systemName: "clock.arrow.circlepath")
                .font(.appCaption2)
                .foregroundColor(.textMutedColor)
            Text("Updated \(date.timeAgoDisplay)")
                .font(.appCaption2)
                .foregroundColor(.textMutedColor)
            Spacer()
        }
    }
}
#Preview("With Lists") {
    DashboardView()
        .environment(\.listService, ListService(
            repository: MockListRepository(),
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
