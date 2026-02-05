//
//  DashboardView.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/3/26.
//

import SwiftUI

import SwiftUI
struct DashboardView: View {
    let lists: [GiftList]
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    ForEach(lists) { list in
                        ListPreviewCard(list: list)
                    }
                }
                .padding(EdgeInsets.appScreenPadding)
            }
            .background(Color.backgroundPrimaryColor)
            .navigationTitle("Dashboard")
        }
    }
}
struct ListPreviewCard: View {
    let list: GiftList
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text(list.name)
                .font(.appTitle3)
                .foregroundColor(.textPrimaryColor)
            HStack {
                Label("\(list.members.count) members", systemImage: "person.2")
                    .font(.appCaption1)
                    .foregroundColor(.textMutedColor)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(EdgeInsets.appCardPadding)
        .background(Color.surfaceColor)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

#Preview("Light Mode") {
    DashboardView(lists: MockData.allLists)
}

#Preview("Dark Mode") {
    DashboardView(lists: MockData.allLists)
        .preferredColorScheme(.dark)
}

#Preview("Empty State") {
    DashboardView(lists: [])
}
