//
//  PrivacyCoverView.swift
//  ChristmasTracker
//

import SwiftUI

struct PrivacyCoverView: View {
    var body: some View {
        ZStack {
            Color.backgroundPrimaryColor
                .ignoresSafeArea()
            Text("Christmas Tracker")
                .font(.appTitle1)
                .foregroundStyle(Color.textPrimaryColor)
        }
        .accessibilityHidden(true)
    }
}
