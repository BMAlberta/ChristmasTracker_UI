//
//  ListSummaryTileView.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 10/4/25.
//

import SwiftUI

struct ListSummaryTile: View {
    var body: some View {
        VStack (alignment: .leading) {
            HStack {
                Text("Sample List Name")
                    .font(.brandFont(size: 20))
                    .foregroundStyle(.primaryText)
                Spacer()
                StateCapsule(state: .active)
            }
            Text("Created by")
                .font(.brandFont(size: 14))
            HStack(spacing:20) {
                Text("8 items")
                    .font(.brandFont(size: 12))
                Text ("2 purchased")
                    .font(.brandFont(size: 12))
                Spacer()
                Text ("000")
            }
            ProgressView(value: 0.4)
            HStack {
                Text("40 % complete")
                    .font(.caption2)
                Spacer()
                Text("Updated Dec 2")
                    .font(.caption2)
                    .foregroundStyle(.primaryRed)
            }
        }
        .padding()
        .background(Color.white) // Apply background color first
        .cornerRadius(6) // Apply corner radius to the view's content and background
        .overlay( // Overlay a rounded rectangle for the border
            RoundedRectangle(cornerRadius: 6)
                .stroke(.border, lineWidth: 1) // Define border color and width
        )
    }
}

#Preview {
    ListSummaryTile()
}
