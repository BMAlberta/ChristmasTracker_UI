//
//  PurchaseHistoryView.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/16/26.
//

import SwiftUI

struct PurchaseHistoryView: View {
    
    let item: GiftItem
    
    @Environment(\.dismiss) private var dismiss
    @State private var purchases: [Purchase] = []
    @State private var isLoading = false
    @State private var error: PurchaseError?
    @State private var selectedPurchaseId: String?
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading && purchases.isEmpty {
                    LoadingView(message: "Loading purchases...")
                } else if let error = error, purchases.isEmpty {
                    ErrorStateView(error: error) {
                        Task { await loadPurchases() }
                    }
                } else if purchases.isEmpty {
                    emptyState
                } else {
                    purchasesList
                }
            }
            .background(Color.backgroundPrimaryColor)
            .navigationTitle("Purchase History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .navigationDestination(item: $selectedPurchaseId) { purchaseId in
                if let purchase = purchases.first(where: { $0.id == purchaseId }) {
                    PurchaseDetailView(purchase: purchase, item: item)
                }
            }
            .task {
                await loadPurchases()
            }
        }
    }
    
    private var emptyState: some View {
        EmptyStateView(
            icon: "cart",
            title: "No Purchases Yet",
            message: "Purchase records will appear here"
        )
    }
    
    private var purchasesList: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                // Summary card
                summaryCard
                
                // Purchases
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    Text("Purchase Records")
                        .font(.appHeadline)
                        .foregroundColor(.textPrimaryColor)
                    
                    ForEach(purchases) { purchase in
                        PurchaseRow(purchase: purchase)
                            .onTapGesture {
                                selectedPurchaseId = purchase.id
                            }
                        
                        if purchase.id != purchases.last?.id {
                            Divider()
                                .padding(.leading, 52)
                        }
                    }
                }
                .padding(AppSpacing.lg)
                .background(Color.surfaceColor)
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
            }
            .padding(EdgeInsets.appScreenPadding)
        }
    }
    
    private var summaryCard: some View {
        VStack(spacing: AppSpacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("Total Purchased")
                        .font(.appCaption1)
                        .foregroundColor(.textMutedColor)
                    Text("\(totalPurchased)")
                        .font(.appTitle2)
                        .foregroundColor(totalPurchased > item.quantityRequested ? .orange : .textPrimaryColor)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: AppSpacing.xs) {
                    Text("Total Spent")
                        .font(.appCaption1)
                        .foregroundColor(.textMutedColor)
                    Text("$\(String(format: "%.2f", totalSpent))")
                        .font(.appTitle2)
                        .foregroundColor(.primaryColor)
                }
            }
            
            // Progress bar
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                HStack {
                    Text("Progress")
                        .font(.appCaption1)
                        .foregroundColor(.textMutedColor)
                    Spacer()
                    Text("\(totalPurchased) of \(item.quantityRequested)")
                        .font(.appCaption1)
                        .foregroundColor(totalPurchased > item.quantityRequested ? .orange : .textMutedColor)
                }
                
                ProgressView(value: min(progress, 1.0))  // Cap at 100%
                    .tint(totalPurchased > item.quantityRequested ? .orange : .primaryColor)
            }
            
            if totalPurchased > item.quantityRequested {
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Purchased \(totalPurchased - item.quantityRequested) more than requested")
                        .font(.appCaption1)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding(AppSpacing.lg)
        .background(Color.surfaceColor)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    private var totalPurchased: Int {
        purchases.reduce(0) { $0 + $1.quantity }
    }
    
    private var totalSpent: Double {
        purchases.reduce(0) { $0 + $1.totalCost }
    }
    
    private var progress: Double {
        guard item.quantityRequested > 0 else { return 0 }
        return Double(totalPurchased) / Double(item.quantityRequested)
    }
    
    private func loadPurchases() async {
        isLoading = true
        error = nil
        
        // TODO: Fetch purchases via PurchaseRepository
        // For now, using mock data
        do {
            try await Task.sleep(nanoseconds: 500_000_000)
        } catch {
            LogError("Mock error: \(error)")
        }
        
        
        // Mock: Filter purchases for this item
        purchases = MockPurchaseData.allPurchases.filter { $0.itemId == item.id }
        
        isLoading = false
    }
}

#Preview {
    PurchaseHistoryView(item: MockItemData.allItems[0])
}
