//
//  ItemDetailView.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/16/26.
//

import SwiftUI

import SwiftUI

struct ItemDetailView: View {
    
    let itemId: String
    
    @Environment(\.itemService) private var itemService
    @Environment(\.dismiss) private var dismiss
    
    @State private var showEditSheet = false
    @State private var showDeleteConfirmation = false
    @State private var showRecordPurchaseSheet = false  // For Phase 6.5
    @State private var showPurchaseConfirmation = false
    @State private var showPurchaseHistorySheet = false
    
    private var item: GiftItem? {
        itemService.items.first { $0.id == itemId }
    }
    
    var body: some View {
        Group {
            if let item = itemService.currentItem {
                detailContent(item: item)
            } else {
                LoadingView(message: "Loading item...")
            }
        }
        .navigationTitle("Item Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if let item = item, item.canEdit {
                    Button("Edit") {
                        showEditSheet = true
                    }
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            if let item = item {
                EditItemView(item: item)
            }
        }
        .sheet(isPresented: $showRecordPurchaseSheet) {
            if let item = item {
                RecordPurchaseView(item: item)
            }
        }
        .sheet(isPresented: $showPurchaseHistorySheet) {
            if let item = item {
                PurchaseHistoryView(item: item)
            }
        }
        .task {
            try? await itemService.loadItemDetail(id: itemId)
        }
        .onDisappear {
            itemService.clearItemDetail()
        }
    }
    
    private func detailContent(item: GiftItem) -> some View {
        ScrollView {
            VStack(spacing: AppSpacing.xl) {
                // Header card
                headerCard(item: item)
                
                // Purchase status card
                if item.isPurchased {
                    purchaseSummaryCard(item: item)
                }
                
                // Actions
                actionsSection(item: item)
            }
            .padding(EdgeInsets.appScreenPadding)
        }
        .background(Color.backgroundPrimaryColor)
        .confirmationDialog(
            "Delete Item",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete '\(item.name)'", role: .destructive) {
                Task {
                    try? await itemService.deleteItem(id: item.id, listId: item.listId)
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This action cannot be undone.")
        }
        .confirmationDialog(
            item.isPurchased ? "Mark as not purchased?" : "Mark as purchased?",
            isPresented: $showPurchaseConfirmation,
            titleVisibility: .visible
        ) {
            if item.isPurchased {
                Button("Undo Purchase") {
                    Task {
                        //                        try? await itemService.undoPurchase(id: item.id)
                    }
                }
            } else {
                Button("Mark as Purchased") {
                    Task {
                        //                        try? await itemService.purchaseItem(id: item.id)
                    }
                }
            }
            Button("Cancel", role: .cancel) { }
        }
    }
    
    private func headerCard(item: GiftItem) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text(item.name)
                .font(.appTitle1)
                .foregroundColor(.textPrimaryColor)
            
            Text(item.description ?? "")
                .font(.appBody)
                .foregroundColor(.textMutedColor)
            
            if let price = item.expectedUnitPrice {
                HStack {
                    Text("Expected Price:")
                        .font(.appHeadline)
                        .foregroundColor(.textMutedColor)
                    Text("$\(String(format: "%.2f", price))")
                        .font(.appHeadline)
                        .foregroundColor(.textPrimaryColor)
                    
                    if item.quantityRequested > 1 {
                        Text("× \(item.quantityRequested)")
                            .font(.appBody)
                            .foregroundColor(.textMutedColor)
                    }
                }
            }
            
            if item.quantityRequested > 1, let totalPrice = item.totalPrice {
                HStack {
                    Text("Total:")
                        .font(.appHeadline)
                        .foregroundColor(.textMutedColor)
                    Text("$\(String(format: "%.2f", totalPrice))")
                        .font(.appTitle3)
                        .foregroundColor(.primaryColor)
                }
            }
            
            // Priority
            if item.priority > 0 {
                HStack {
                    Text("Priority:")
                        .font(.appBody)
                        .foregroundColor(.textMutedColor)
                    HStack(spacing: 2) {
                        ForEach(1...10, id: \.self) { level in
                            Image(systemName: level <= item.priority ? "star.fill" : "star")
                                .foregroundColor(.orange)
                                .font(.appCaption2)
                        }
                    }
                }
            }
            
            if let url = item.url {
                Link(destination: URL(string: url)!) {
                    HStack {
                        Image(systemName: "link")
                        Text("View Product")
                    }
                    .font(.appBody)
                    .foregroundColor(.accentColor)
                }
            }
            
            if item.offList {
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "gift.fill")
                    Text("Surprise Gift - Hidden from list owner")
                }
                .font(.appCaption1)
                .foregroundColor(.orange)
                .padding(.horizontal, AppSpacing.sm)
                .padding(.vertical, AppSpacing.xs)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(4)
            }
            
            // Status badge
            HStack {
                Image(systemName: item.status.icon)
                    .foregroundColor(item.status.color)
                Text(item.status.displayName)
                    .font(.appHeadline)
                    .foregroundColor(item.status.color)
            }
        }
        .padding(AppSpacing.lg)
        .background(Color.surfaceColor)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    private func purchaseSummaryCard(item: GiftItem) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("Purchase Status")
                        .font(.appHeadline)
                        .foregroundColor(.textPrimaryColor)
                    
                    if let purchasedQuantity = item.totalQuantityPurchased {
                        Text("\(purchasedQuantity) of \(item.quantityRequested) purchased")
                            .font(.appBody)
                            .foregroundColor(.textMutedColor)
                    }
                }
                
                Spacer()
                
                Button {
                    showPurchaseHistorySheet = true
                } label: {
                    HStack(spacing: AppSpacing.xs) {
                        Text("View History")
                        Image(systemName: "chevron.right")
                    }
                    .font(.appCaption1)
                    .foregroundColor(.accentColor)
                }
            }
            
            // Progress bar
            if let purchaseQuantity = item.totalQuantityPurchased {
                ProgressView(value: Double(purchaseQuantity) / Double(item.quantityRequested))
                    .tint(item.status.color)
            }
        }
        .padding(AppSpacing.lg)
        .background(Color.surfaceColor)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    private func actionsSection(item: GiftItem) -> some View {
        VStack(spacing: AppSpacing.md) {
            // Record Purchase button
            if !item.isPurchased || item.status == .partial {
                Button {
                    showRecordPurchaseSheet = true
                } label: {
                    HStack {
                        Image(systemName: "cart.badge.plus")
                        Text(item.status == .partial ? "Record Additional Purchase" : "Record Purchase")
                    }
                    .font(.appHeadline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.md)
                    .background(Color.green)
                    .cornerRadius(12)
                }
            }
            
            // View Purchase History button
            if item.status != .available {
                Button {
                    showPurchaseHistorySheet = true
                } label: {
                    HStack {
                        Image(systemName: "clock.arrow.circlepath")
                        Text("View Purchase History")
                    }
                    .font(.appHeadline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.md)
                    .background(Color.blue)
                    .cornerRadius(12)
                }
            }
            
            // Delete button (if can edit)
            if item.canEdit {
                Button {
                    showDeleteConfirmation = true
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text("Delete Item")
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
}

#Preview {
    NavigationStack {
        ItemDetailView(itemId: "1")
            .environment(\.itemService, {
                let service = ItemService(
                    repository: MockItemRepository(),
                    dataStore: ItemDataStore()
                )
                Task {
                    await service.loadItems(listId: "1")
                }
                return service
            }())
    }
}
