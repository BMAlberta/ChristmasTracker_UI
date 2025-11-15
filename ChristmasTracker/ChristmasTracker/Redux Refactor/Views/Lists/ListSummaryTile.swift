//
//  ListSummaryTileView.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 10/4/25.
//

import SwiftUI

struct ListSummaryTile: View {
    var listSummary: ListSummary
    var body: some View {
        VStack (alignment: .leading) {
            HStack {
                Text(listSummary.name)
                    .font(.brandFont(size: 20))
                    .foregroundStyle(.primaryText)
                Spacer()
                StateCapsule(state: listSummary.status)
            }
            Text("Created by \(listSummary.ownerInfo.firstName)")
                .font(.brandFont(size: 14))
            HStack(spacing:20) {
                Text("\(listSummary.totalItems) items")
                    .font(.brandFont(size: 12))
                if (listSummary.canViewMetadata) {
                    Text ("\(listSummary.purchasedItems) purchased")
                        .font(.brandFont(size: 12))
                }
                Spacer()
                AvatarListView(initials: ["BA","MA","NC","DC"], maxAvatars: 3)
            }

            if (listSummary.canViewMetadata) {
                ProgressView(value: purchaseProgress)
            }
            EmptyView()
            SummaryFooterView
                .padding(EdgeInsets(top: 2, leading: 0, bottom: 0, trailing: 0))
        }
        .padding()
        .background(Color.white) // Apply background color first
        .cornerRadius(6) // Apply corner radius to the view's content and background
        .overlay( // Overlay a rounded rectangle for the border
            RoundedRectangle(cornerRadius: 6)
                .stroke(.border, lineWidth: 1) // Define border color and width
        )
    }
    
    private var SummaryFooterView: some View {
        HStack {

            if (listSummary.canViewMetadata) {
                Text("\(purchasePercentage) % complete")
                    .font(.caption2)
            }
            Spacer()
            Text("Updated \(FormatUtility.convertDateOnlyStringToHumanReadable(rawDate: listSummary.lastUpdateDate))")
                .font(.caption2)
                .foregroundStyle(.primaryRed)
        }
    }
    
    private var purchasePercentage: Int {
        return Int(purchaseProgress * 100)
    }
    
    private var purchaseProgress: Double {
        guard listSummary.totalItems > 0 else {
            return 0
        }
        return Double(listSummary.purchasedItems)/Double(listSummary.totalItems)
    }
}

#Preview {
    ListSummaryTile(listSummary: ListSummary(id: "1",
                                             name: "Sample List",
                                             listTheme: "Sample theme",
                                             ownerInfo: LWUserModel(id: "1",
                                                                firstName: "Jim",
                                                                lastName: "Johnson"),
                                             status: .active,
                                             creationDate: "2025-09-18T04:55:38.000Z",
                                             lastUpdateDate: "2025-09-18T04:55:38.000Z",
                                             totalItems: 9,
                                             purchasedItems: 2,
                                             members: [], items: [], canViewMetadata: false))
}

#Preview {
    ListSummaryTile(listSummary: ListSummary(id: "1",
                                             name: "Sample List",
                                             listTheme: "Sample theme",
                                             ownerInfo: LWUserModel(id: "1",
                                                                firstName: "Jim",
                                                                lastName: "Johnson"),
                                             status: .active,
                                             creationDate: "2025-09-18T04:55:38.000Z",
                                             lastUpdateDate: "2025-09-18T04:55:38.000Z",
                                             totalItems: 9,
                                             purchasedItems: 2,
                                             members: [], items: [], canViewMetadata: true))
    .preferredColorScheme(.dark)
}
