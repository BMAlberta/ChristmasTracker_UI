//
//  GreetingView.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 9/29/25.
//

import SwiftUI

struct GreetingView_legacy: View {
    var body: some View {
        VStack {
            GreetingBody
                .frame(height: 100)
                .cornerRadius(6)
                .padding()
            ButtonGroupView
                .padding()
            FilterCarousel
                .padding()
            
//            ForEach(0..<5) { _ in
//                ListTileView
//                    .padding()
//                    .border(.border)
//                    .background(.white)
//                    .padding(EdgeInsets(top: 0, leading: 20, bottom: 20, trailing: 20))
//            }
            
//            ItemTileView
//                .padding()
//                .border(.border)
//                .background(.white)
//                .padding()
                
        }
        .background(Color.background)
        
//        List {
//            GreetingBody
//                .frame(height: 100)
//                .cornerRadius(6)
//                .listRowBackground(Color.clear)
//                .listRowSeparator(.hidden)
//
//            ButtonGroupView
//                .listRowBackground(Color.clear)
//                .listRowSeparator(.hidden)
//            
//            Section(header: Text("My Lists")) {
//                FilterCarousel
//                    .listRowSeparator(.hidden)
//                    
//            }
//
//        }
//        .listStyle(.plain)
//        .scrollContentBackground(.hidden)
//        .background(Color.background)
        
    }
    
    var GreetingBody: some View {
        HStack {
            Spacer()
            VStack(alignment: .leading) {
                Spacer()
                Text("Welcome back, User!")
                    .font(.brandFont(size: 20))
                    .foregroundStyle(Color.white)
                Spacer()
                Text ("There are X days until Christmas")
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
    }
    
    
    
    var FilterCarousel: some View {
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
    
    
    var CapsuleView: some View {
        Text("Active")
            .font(.system(size: 10))
            .fontWeight(.bold)
            .font(.callout)
            .padding(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            .foregroundColor(Color.white)
            .background(.primaryGreen)
            .clipShape(Capsule())
    }
    
    var ListTileView: some View {
        VStack (alignment: .leading) {
            HStack {
                Text("Sample List Name")
                    .font(.brandFont(size: 20))
                    .foregroundStyle(.primaryText)
                Spacer()
                CapsuleView
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
    }
    
    var ButtonGroupView: some View {
        HStack(spacing: 20) {
            
            Button {} label: {
                Label("New List", systemImage: "plus")
                    .font(.brandFont(size: 20))
                    .foregroundColor(.white)
                    .padding()
                    .frame(minWidth: 50, maxWidth: .infinity)
                    .background(.primaryRed)
                    .cornerRadius(6.0)
                    
            }
            
            Button { } label: {
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
        }
    }
    
    var ItemTileView: some View {
        HStack(alignment: .top) {
            Text("Preview")
            VStack(alignment: .leading) {
                HStack {
                    Text("Item Name")
                        .font(.brandFont(size: 20))
                        .foregroundStyle(.primaryText)
                    Spacer()
                    CapsuleView
                }
                Text("Item Description")
                    .font(.brandFont(size: 16))
                    .foregroundStyle(.secondaryText)
                HStack(spacing: 20) {
                    Text("Item Price")
                        .font(.brandFont(size: 18))
                        .foregroundStyle(.primaryRed)
                    Text("Quantity")
                        .font(.brandFont(size: 18))
                        .foregroundStyle(.secondaryText)
                    Spacer()
                    Image("openLinkImage")
                        .resizable()
                        .scaledToFit()
                        .frame(width:15,height: 30)
                        .foregroundStyle(.buttonText)
                }
            }
        }
    }
    
    
    
    
}

#Preview {
    GreetingView_legacy()
}
