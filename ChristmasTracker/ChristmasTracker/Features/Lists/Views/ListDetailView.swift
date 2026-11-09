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
    
    @State private var showEditSheet = false
    @State private var showDeleteConfirmation = false
    @State private var showAddItemSheet = false
    @State private var selectedItemId: String?
    
    var body: some View {
        Group {
            if listService.isLoading && listService.currentListDetail == nil {
                LoadingView(message: "Loading list...")
            } else if let error = listService.error {
                ErrorStateView(error: error) {
                    Task { await listService.loadListDetail(id: listId) }
                }
            } else if let detail = listService.currentListDetail {
                detailContent(detail: detail)
            }
        }
        .background(Color.backgroundPrimaryColor)
        .navigationTitle("List Details")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedItemId) { itemId in
            ItemDetailView(itemId: itemId)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if let detail = listService.currentListDetail,
                   ListPermissions(detail.capabilities).canEditList {
                    Button("Edit") {
                        showEditSheet = true
                    }
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            if let detail = listService.currentListDetail {
                EditListView(list: detail)
            }
        }
        .task {
            await listService.loadListDetail(id: listId)
            await itemService.loadItems(listId: listId)
        }
    }
    private func detailContent(detail: ListDetail) -> some View {
        let permissions = ListPermissions(detail.capabilities)
        return ScrollView {
            VStack(spacing: AppSpacing.xl) {
                headerCard(detail: detail)
                if permissions.showsCounts(itemCount: detail.itemCount, purchasedCount: detail.purchasedCount) {
                    statsCard(detail: detail)
                }
                
                itemsSection(detail: detail)
                
                if permissions.showsMembersSection, let members = detail.members {
                    membersCard(members: members)
                }
               
                if permissions.canDeleteList {
                    actionsSection()
                }
            }
            .padding(EdgeInsets.appScreenPadding)
        }
        .confirmationDialog(
            "Are you sure you want to delete this list?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete List", role: .destructive) {
                Task {
                    try? await listService.deleteList(id: detail.id)
                    dismiss()
                }
            }
        } message: {
            Button("Cancel", role: .cancel) { }
            Text("This action cannot be undone. All items will be permanently deleted.")
        }
    }
    private func headerCard(detail: ListDetail) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(detail.name)
                        .font(.appTitle1)
                        .foregroundColor(.textPrimaryColor)
                    Text("For \(detail.recipientName)")
                        .font(.appTitle3)
                        .foregroundColor(.textMutedColor)
                }
                Spacer()
                Text(ListRoleBadge(detail: detail).title)
                    .font(.appCaption1)
                    .foregroundColor(.white)
                    .padding(.horizontal, AppSpacing.sm)
                    .padding(.vertical, AppSpacing.xs)
                    .background(ListRoleBadge(detail: detail).tone.color)
                    .cornerRadius(4)
            }
            if let theme = detail.theme {
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "sparkles")
                        .font(.appCaption1)
                        .foregroundColor(.accentColor)
                    Text(theme)
                        .font(.appBody)
                        .foregroundColor(.accentColor)
                }
            }
            HStack {
                Label("\(detail.year.yearDisplay)", systemImage: "calendar")
                    .font(.appCaption1)
                    .foregroundColor(.textMutedColor)
                Spacer()
                Label(detail.visibility.displayName, systemImage: detail.visibility.icon)
                    .font(.appCaption1)
                    .foregroundColor(.textMutedColor)
            }
            .padding(.top, AppSpacing.xs)
        }
        .padding(AppSpacing.lg)
        .background(Color.surfaceColor)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    private func statsCard(detail: ListDetail) -> some View {
        VStack(spacing: AppSpacing.md) {
            Text("Progress")
                .font(.appHeadline)
                .foregroundColor(.textPrimaryColor)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let itemCount = detail.itemCount,
               let purchasedCount = detail.purchasedCount {
                HStack(spacing: AppSpacing.lg) {
                    statItem(
                        icon: "list.bullet",
                        value: "\(purchasedCount)/\(itemCount)",
                        label: "Items"
                    )
                    Spacer()
                }
                if let progress = detail.progress {
                    ProgressView(value: progress)
                        .tint(.primaryColor)
                }
            }
        }
        .padding(AppSpacing.lg)
        .background(Color.surfaceColor)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    private func statItem(icon: String, value: String, label: String) -> some View {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: icon)
                .font(.appBody)
                .foregroundColor(.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.appHeadline)
                    .foregroundColor(.textPrimaryColor)
                Text(label)
                    .font(.appCaption2)
                    .foregroundColor(.textMutedColor)
            }
        }
    }
    private func membersCard(members: [ListMember]) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack {
                Text("Members")
                    .font(.appHeadline)
                    .foregroundColor(.textPrimaryColor)
                Spacer()
                Text("\(members.count)")
                    .font(.appCaption1)
                    .foregroundColor(.textMutedColor)
            }
            ForEach(members) { member in
                HStack(spacing: AppSpacing.md) {
                    Circle()
                        .fill(Color.primaryColor.opacity(0.2))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Text(String(member.displayName.prefix(1)))
                                .font(.appHeadline)
                                .foregroundColor(.primaryColor)
                        )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(member.displayName)
                            .font(.appBody)
                            .foregroundColor(.textPrimaryColor)
                        if let email = member.email {
                            Text(email)
                                .font(.appCaption1)
                                .foregroundColor(.textMutedColor)
                        }
                    }
                    Spacer()
                    Text(member.role.displayName)
                        .font(.appCaption1)
                        .foregroundColor(.textMutedColor)
                }
            }
        }
        .padding(AppSpacing.lg)
        .background(Color.surfaceColor)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    private func actionsSection() -> some View {
        VStack(spacing: AppSpacing.md) {
            Button {
                showDeleteConfirmation = true
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text("Delete List")
                }
                .font(.appHeadline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.md)
                .background(Color.red)
                .cornerRadius(12)
            }
        }
    }
    
    private func itemsSection(detail: ListDetail) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack {
                Text("Items")
                    .font(.appHeadline)
                    .foregroundColor(.textPrimaryColor)
                Spacer()
                if !itemService.items.isEmpty {
                    Text("\(itemService.filteredItems.count)")
                        .font(.appCaption1)
                        .foregroundColor(.textMutedColor)
                }
            }
            if itemService.isLoading && itemService.items.isEmpty {
                // Loading
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.xl)
            } else if itemService.items.isEmpty {
                // Empty state
                VStack(spacing: AppSpacing.md) {
                    Image(systemName: "gift.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.textMutedColor)
                    Text("No items yet")
                        .font(.appBody)
                        .foregroundColor(.textMutedColor)
                    if detail.capabilities.canCreateItem {
                        Button("Add First Item") {
                            showAddItemSheet = true
                        }
                        .font(.appHeadline)
                        .foregroundColor(.primaryColor)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.xl)
            } else {
                // Items list
                ForEach(itemService.filteredItems) { item in
                    ItemRow(item: item, detail: detail)
                        .onTapGesture {
                            selectedItemId = item.id
                        }
                    if item.id != itemService.filteredItems.last?.id {
                        Divider()
                            .padding(.leading, 52)
                    }
                }
            }
        }
        .padding(AppSpacing.lg)
        .background(Color.surfaceColor)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
}
// MARK: - ListVisibility Extension
extension ListVisibility {
    var displayName: String {
        switch self {
        case .private: return "Private"
        case .inviteOnly: return "Invite Only"
        case .friendsOnly: return "Friends Only"
        case .public: return "Public"
        }
    }
    var icon: String {
        switch self {
        case .private: return "lock.fill"
        case .inviteOnly: return "person.2.fill"
        case .friendsOnly: return "person.crop.circle.badge.checkmark"
        case .public: return "globe"
        }
    }
}
#Preview {
    NavigationStack {
        ListDetailView(listId: "1")
            .environment(\.listService, ListService(
                repository: MockListRepository(),
                dataStore: ListDataStore()
            ))
    }
}
