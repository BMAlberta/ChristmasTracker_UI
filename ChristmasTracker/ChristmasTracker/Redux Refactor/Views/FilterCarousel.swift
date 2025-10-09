//
//  FIlterCarousel.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 10/4/25.
//

import SwiftUI

struct FilterCarousel: View {
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 20) {
                ForEach(0..<10) { index in
                    Button("Log in") { }
                        .padding(.vertical, 5)
                        .padding(.horizontal, 20)
                        .foregroundColor(.white)
                        .background(Capsule().fill(.primaryRed))
                }
            }
        }
    }
}

#Preview {
    FilterCarousel()
}
