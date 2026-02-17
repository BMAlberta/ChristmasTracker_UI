//
//  PurchaseRow.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/16/26.
//

import SwiftUI

/// Row displaying purchase summary
struct PurchaseRow: View {
    
    let purchase: Purchase
    
    var body: some View {
        HStack(spacing: AppSpacing.md) {
            // Status icon
            Image(systemName: purchase.shippingStatus.icon)
                .font(.system(size: 24))
                .foregroundColor(purchase.shippingStatus.color)
            
            // Purchase info
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                HStack {
                    Text("\(purchase.quantity) × $\(String(format: "%.2f", purchase.unitCost))")
                        .font(.appBody)
                        .foregroundColor(.textPrimaryColor)
                    
                    Spacer()
                    
                    Text("$\(String(format: "%.2f", purchase.totalCost))")
                        .font(.appHeadline)
                        .foregroundColor(.primaryColor)
                }
                
                if let store = purchase.storeName {
                    Text(store)
                        .font(.appCaption1)
                        .foregroundColor(.textMutedColor)
                }
                
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: purchase.shippingStatus.icon)
                        .font(.appCaption2)
                    Text(purchase.shippingStatus.displayName)
                }
                .font(.appCaption2)
                .foregroundColor(purchase.shippingStatus.color)
                
                Text(purchase.purchasedAt.timeAgoDisplay)
                    .font(.appCaption2)
                    .foregroundColor(.textMutedColor)
            }
            
            Image(systemName: "chevron.right")
                .font(.appCaption1)
                .foregroundColor(.textMutedColor)
        }
        .padding(.vertical, AppSpacing.sm)
    }
}

#Preview {
    VStack {
        PurchaseRow(purchase: MockPurchaseData.allPurchases[0])
        Divider()
    }
    .padding()
}
