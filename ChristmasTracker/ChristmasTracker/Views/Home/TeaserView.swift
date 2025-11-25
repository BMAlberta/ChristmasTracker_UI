//
//  TeaserView.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 10/4/25.
//

import SwiftUI

struct TeaserView: View {
    let teaser: Teaser

    var body: some View {
        HStack {
            Spacer()
            VStack(alignment: .leading) {
                Spacer()
                Text("Welcome back, \(teaser.name)!")
                    .font(.brandFont(size: 20))
                    .foregroundStyle(Color.white)
                Spacer()
                Text (teaser.message)
                    .font(.brandFont(size: 14))
                    .foregroundStyle(Color.white)
                Spacer()
            }
            Spacer()
            Image("snowflake")
                .resizable()
                .scaledToFit()
                .frame(width:40)
            Spacer()
        }
        .background(
            LinearGradient(gradient: Gradient(colors: [ .primaryRed, .primaryGreen]), startPoint: .leading, endPoint: .trailing)
        )
        .frame(height: 100)
        .cornerRadius(6)
    }
}

#Preview {
    TeaserView(teaser: Teaser(type: .greeting, name: "John", message: "Sample teaser text here"))
}

#Preview {
    TeaserView(teaser: Teaser(type: .greeting, name: "John", message: "Sample teaser text here"))
        .preferredColorScheme(.dark)
}
