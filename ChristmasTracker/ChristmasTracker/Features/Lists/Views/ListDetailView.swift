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
                if let detail = listService.currentListDetail, detail.canEdit {
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
        ScrollView {
            VStack(spacing: AppSpacing.xl) {
                headerCard(detail: detail)
                if detail.itemCount != nil {
                    statsCard(detail: detail)
                }
                
                itemsSection(detail: detail)
                
                membersCard(detail: detail)
               
                if detail.canEdit {
                    actionsSection(detail: detail)
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
                Text(detail.myRole.displayName)
                    .font(.appCaption1)
                    .foregroundColor(.white)
                    .padding(.horizontal, AppSpacing.sm)
                    .padding(.vertical, AppSpacing.xs)
                    .background(detail.myRole.color)
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
            if let description = detail.description {
                Text(description)
                    .font(.appBody)
                    .foregroundColor(.textMutedColor)
                    .padding(.top, AppSpacing.xs)
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
                    if let budget = detail.totalBudget,
                       let spent = detail.totalSpent {
                        statItem(
                            icon: "dollarsign.circle",
                            value: "$\(Int(spent))/$\(Int(budget))",
                            label: "Budget"
                        )
                    }
                    Spacer()
                }
                ProgressView(value: detail.progress)
                    .tint(.primaryColor)
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
    private func membersCard(detail: ListDetail) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack {
                Text("Members")
                    .font(.appHeadline)
                    .foregroundColor(.textPrimaryColor)
                Spacer()
                Text("\(detail.members.count)")
                    .font(.appCaption1)
                    .foregroundColor(.textMutedColor)
            }
            ForEach(detail.members) { member in
                HStack(spacing: AppSpacing.md) {
                    Circle()
                        .fill(Color.primaryColor.opacity(0.2))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Text(String(member.userName.prefix(1)))
                                .font(.appHeadline)
                                .foregroundColor(.primaryColor)
                        )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(member.userName)
                            .font(.appBody)
                            .foregroundColor(.textPrimaryColor)
                        if let email = member.userEmail {
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
    private func actionsSection(detail: ListDetail) -> some View {
        VStack(spacing: AppSpacing.md) {
            if detail.myRole == .owner {
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
                    if detail.canEdit {
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
        case .public: return "Public"
        }
    }
    var icon: String {
        switch self {
        case .private: return "lock.fill"
        case .inviteOnly: return "person.2.fill"
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
