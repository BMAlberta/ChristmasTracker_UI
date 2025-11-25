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


struct FilterCarouselView: View {
    @Binding var selectedFilter: FilterItem
    let onFilterSelected: (FilterItem) -> Void
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(FilterItem.allCases) { filter in
                    FilterItemView(
                        filter: filter,
                        isSelected: selectedFilter == filter
                    ) {
                        selectedFilter = filter
                        onFilterSelected(filter)
                    }
                }
            }
        }
        
    }
}

struct FilterItemView: View {
    let filter: FilterItem
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(filter.rawValue)
                .font(.brandFont(size: 14))
                .fontWeight(.semibold)
                .foregroundColor(isSelected ? .white : .secondaryText)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(isSelected ? .primaryRed : .secondaryAccent)
                ).overlay(
                    Capsule()
                        .stroke(.border, lineWidth: 1)
                )
        }
    }
}

enum FilterItem: String, CaseIterable, Identifiable {
    case all = "All"
    case myLists = "My Lists"
    case joined = "Joined"
    case active = "Active"
    case archived = "Archived"
    
    var id: String {
        self.rawValue
    }
}

struct SampleFilterView: View {
    @State private var currentFilter: FilterItem = .all
    
    var body: some View {
        
        FilterCarouselView(selectedFilter: $currentFilter) { selectedFilter in
            print("Selected filter: \(selectedFilter.rawValue)")
        }
    }
}


#Preview {
    SampleFilterView()
}

#Preview {
    SampleFilterView()
        .preferredColorScheme(.dark)
}

