//
//  HomeFeedButtonGroup.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 10/4/25.
//

import SwiftUI

struct HomeFeedButtonGroup: View {
    let onNewList: () -> Void
    let onJoinList: () -> Void
    
    
    var body: some View {
        HStack(spacing: 20) {

            Button(action: onNewList) {
                Label("New List", systemImage: "plus")
                    .font(.brandFont(size: 20))
                    .foregroundColor(.white)
                    .padding()
                    .frame(minWidth: 50, maxWidth: .infinity)
                    .background(.primaryRed)
                    .cornerRadius(6.0)
            }
            .buttonStyle(.borderless)
            
            
            Button(action: onJoinList) {
                Label("Join List", systemImage: "person.fill.badge.plus")
                    .font(.brandFont(size: 20))
                    .foregroundColor(.primaryText)
                    .padding()
                    .frame(minWidth: 50, maxWidth: .infinity)
                    .background(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius:6) // Adjust cornerRadius as needed
                            .stroke(.border, lineWidth: 1) // Gray border with 2pt width
                    )
            }
            .buttonStyle(.borderless)
        }
    }
}

#Preview {
    HomeFeedButtonGroup(onNewList: {}, onJoinList: {})
}

#Preview {
    HomeFeedButtonGroup(onNewList: {}, onJoinList: {})
        .preferredColorScheme(.dark)
}
