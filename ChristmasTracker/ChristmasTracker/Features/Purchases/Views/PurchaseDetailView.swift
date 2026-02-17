//
//  PurchaseDetailView.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/16/26.
//

import SwiftUI

struct PurchaseDetailView: View {
    
    let purchase: Purchase
    let item: GiftItem
    
    @Environment(\.dismiss) private var dismiss
    @State private var showEditSheet = false
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.xl) {
                // Purchase info card
                purchaseInfoCard
                
                // Shipping card
                shippingCard
                
                // Order details card
                orderDetailsCard
                
                // Actions
                if canEdit {
                    actionsSection
                }
            }
            .padding(EdgeInsets.appScreenPadding)
        }
        .background(Color.backgroundPrimaryColor)
        .navigationTitle("Purchase Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if canEdit {
                    Button("Edit") {
                        showEditSheet = true
                    }
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            EditPurchaseView(purchase: purchase)
        }
        .confirmationDialog(
            "Delete Purchase",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Purchase", role: .destructive) {
                Task {
                    await deletePurchase()
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will remove this purchase record and update the item status.")
        }
    }
    
    private var canEdit: Bool {
        // Can edit own purchases
        purchase.purchaser.id == "current-user"  // TODO: Check against actual user ID
    }
    
    private var purchaseInfoCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text(item.name)
                .font(.appTitle2)
                .foregroundColor(.textPrimaryColor)
            
            Divider()
            
            HStack {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("Quantity")
                        .font(.appCaption1)
                        .foregroundColor(.textMutedColor)
                    Text("\(purchase.quantity)")
                        .font(.appTitle3)
                        .foregroundColor(.textPrimaryColor)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: AppSpacing.xs) {
                    Text("Total Cost")
                        .font(.appCaption1)
                        .foregroundColor(.textMutedColor)
                    Text("$\(String(format: "%.2f", purchase.totalCost))")
                        .font(.appTitle3)
                        .foregroundColor(.primaryColor)
                }
            }
            
            HStack {
                Text("Unit Cost:")
                    .font(.appBody)
                    .foregroundColor(.textMutedColor)
                Spacer()
                Text("$\(String(format: "%.2f", purchase.unitCost))")
                    .font(.appBody)
                    .foregroundColor(.textPrimaryColor)
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                HStack {
                    Text("Purchased by:")
                        .font(.appCaption1)
                        .foregroundColor(.textMutedColor)
                    Spacer()
                    Text(purchase.purchaser.displayName)
                        .font(.appBody)
                        .foregroundColor(.textPrimaryColor)
                }
                
                HStack {
                    Text("For:")
                        .font(.appCaption1)
                        .foregroundColor(.textMutedColor)
                    Spacer()
                    Text(purchase.recipient.displayName)
                        .font(.appBody)
                        .foregroundColor(.textPrimaryColor)
                }
                
                HStack {
                    Text("Purchased:")
                        .font(.appCaption1)
                        .foregroundColor(.textMutedColor)
                    Spacer()
                    Text(purchase.purchasedAt.fullDateTimeString)
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
    
    private var shippingCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack {
                Image(systemName: purchase.shippingStatus.icon)
                    .font(.system(size: 24))
                    .foregroundColor(purchase.shippingStatus.color)
                
                Text("Shipping Status")
                    .font(.appHeadline)
                    .foregroundColor(.textPrimaryColor)
            }
            
            HStack {
                Text(purchase.shippingStatus.displayName)
                    .font(.appTitle3)
                    .foregroundColor(purchase.shippingStatus.color)
                
                Spacer()
            }
            
            if let shippedAt = purchase.shippedAt {
                HStack {
                    Text("Shipped:")
                        .font(.appCaption1)
                        .foregroundColor(.textMutedColor)
                    Spacer()
                    Text(shippedAt.fullDateTimeString)
                        .font(.appCaption1)
                        .foregroundColor(.textPrimaryColor)
                }
            }
            
            if let deliveredAt = purchase.deliveredAt {
                HStack {
                    Text("Delivered:")
                        .font(.appCaption1)
                        .foregroundColor(.textMutedColor)
                    Spacer()
                    Text(deliveredAt.fullDateTimeString)
                        .font(.appCaption1)
                        .foregroundColor(.textPrimaryColor)
                }
            }
            
            if let tracking = purchase.trackingNumber {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("Tracking Number")
                        .font(.appCaption1)
                        .foregroundColor(.textMutedColor)
                    Text(tracking)
                        .font(.appBody)
                        .foregroundColor(.textPrimaryColor)
                        .textSelection(.enabled)
                }
            }
        }
        .padding(AppSpacing.lg)
        .background(Color.surfaceColor)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    private var orderDetailsCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Order Details")
                .font(.appHeadline)
                .foregroundColor(.textPrimaryColor)
            
            if let store = purchase.storeName {
                HStack {
                    Text("Store:")
                        .font(.appBody)
                        .foregroundColor(.textMutedColor)
                    Spacer()
                    Text(store)
                        .font(.appBody)
                        .foregroundColor(.textPrimaryColor)
                }
            }
            
            if let confirmation = purchase.confirmationNumber {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("Confirmation Number")
                        .font(.appCaption1)
                        .foregroundColor(.textMutedColor)
                    Text(confirmation)
                        .font(.appBody)
                        .foregroundColor(.textPrimaryColor)
                        .textSelection(.enabled)
                }
            }
            
            if let notes = purchase.notes {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("Notes")
                        .font(.appCaption1)
                        .foregroundColor(.textMutedColor)
                    Text(notes)
                        .font(.appBody)
                        .foregroundColor(.textPrimaryColor)
                }
            }
        }
        .padding(AppSpacing.lg)
        .background(Color.surfaceColor)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    private var actionsSection: some View {
        VStack(spacing: AppSpacing.md) {
            Button {
                showDeleteConfirmation = true
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text("Delete Purchase")
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
    
    private func deletePurchase() async {
        // TODO: Implement delete via PurchaseRepository
        dismiss()
    }
}

#Preview {
    NavigationStack {
        PurchaseDetailView(
            purchase: MockPurchaseData.allPurchases[0],
            item: MockItemData.allItems[0]
        )
    }
}
