//
//  StatsView.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/13/26.
//

import SwiftUI

struct StatsView: View {
    var body: some View {
        NavigationStack {
            EmptyStateView(icon: "chart.bar.fill",
                           title: "Statistics coming soon",
                           message: "Track your spending and budget process across all your lists")
            .background(Color.backgroundPrimaryColor)
            .navigationTitle("Statistics")
        }
    }
}

#Preview {
    StatsView()
}
