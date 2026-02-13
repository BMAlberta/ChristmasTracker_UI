//
//  ListPreviewCard.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/12/26.
//

import SwiftUI

struct ListPreviewCard: View {
    
    let list: GiftList
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            ListPreviewCardHeader(
                title: list.name,
                subtitle: "For \(list.recipientName)",
                roleDisplayName: list.myRole.displayName,
                roleColor: list.myRole.color
            )
            
            Divider()
            
            if let itemCount = list.itemCount,
               let purchasedCount = list.purchasedCount {
                ListStatsSection(
                    itemCount: itemCount,
                    purchasedCount: purchasedCount,
                    progress: list.progress
                )
            } else {
                ListStatsHiddenNote()
            }
        }
        .padding(AppSpacing.lg)
        .background(Color.surfaceColor)
        .clipShape(.rect(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

private struct ListPreviewCardHeader: View {
    
    let title: String
    let subtitle: String
    let roleDisplayName: String
    let roleColor: Color
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(title)
                    .font(.appTitle3)
                    .foregroundStyle(Color.textPrimaryColor)
                
                Text(subtitle)
                    .font(.appBody)
                    .foregroundStyle(Color.textMutedColor)
            }
            
            Spacer()
            
            RoleBadge(
                displayName: roleDisplayName,
                color: roleColor
            )
        }
    }
}

private struct RoleBadge: View {
    
    let displayName: String
    let color: Color
    
    var body: some View {
        Text(displayName)
            .font(.appCaption1)
            .foregroundStyle(Color.white)
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, AppSpacing.xs)
            .background(color)
            .clipShape(.rect(cornerRadius: 4))
    }
}

private struct ListStatsSection: View {
    
    let itemCount: Int
    let purchasedCount: Int
    let progress: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            ListStatsRow(
                itemCount: itemCount,
                purchasedCount: purchasedCount
            )
            
            ProgressView(value: progress)
                .tint(.primaryColor)
        }
    }
}

private struct ListStatsRow: View {
    
    let itemCount: Int
    let purchasedCount: Int
    
    var body: some View {
        HStack(spacing: AppSpacing.lg) {
            ListStatItem(
                icon: "list.bullet",
                value: "\(purchasedCount)/\(itemCount)",
                label: "Items"
            )
            
            Spacer()
        }
    }
}

private struct ListStatItem: View {
    
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: icon)
                .font(.appBody)
                .foregroundStyle(Color.accentColor)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.appHeadline)
                    .foregroundStyle(Color.textPrimaryColor)
                
                Text(label)
                    .font(.appCaption2)
                    .foregroundStyle(Color.textMutedColor)
            }
        }
    }
}

private struct ListStatsHiddenNote: View {
    
    var body: some View {
        Text("Item details hidden (you're the owner)")
            .font(.appCaption1)
            .foregroundStyle(Color.textMutedColor)
            .italic()
    }
}

#Preview {
    ListPreviewCard(
        list: GiftList(
            id: "1",
            name: "Christmas 2024",
            theme: "Classic",
            year: 2024,
            visibility: .private,
            status: .active,
            recipient: ListPerson(id: "recipient-1", displayName: "Tommy"),
            owner: ListPerson(id: "owner-1", displayName: "Brian"),
            coOwner: nil,
            myRole: .owner,
            itemCount: 12,
            purchasedCount: 8,
            createdAt: Date(),
            updatedAt: Date()
        )
    )
    .padding()
}
