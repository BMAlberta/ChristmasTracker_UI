//
//  HomeView.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 10/4/25.
//

import SwiftUI

struct HomeView: View {
    private var store: Store<AppState>
    @StateObject private var viewStore: ViewStore<HomeViewState>
    
    
    init(store: Store<AppState>) {
        self.store = store
        self._viewStore = StateObject(wrappedValue: ViewStore(
            store: store,
            observe: { appState in
                HomeViewState(
                    isLoading: appState.list.isLoading,
                    teaser: appState.list.teaser
                )
            }
        ))
    }
    
    
    
    var body: some View {
        List {
            TeaserView(teaser: viewStore.state.teaser)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            
            HomeFeedButtonGroup(onNewList: {print("New List Tapped")}, onJoinList: {print("Join List Tapped")})
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            
            FilterCarousel()
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            
            ForEach(0..<5) { _ in
                ListSummaryTile()
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
            
        }
        .onAppear {
            // CRITICAL: Update viewStore with environment store
            viewStore.updateStore(store)
//            if viewStore.state.products.isEmpty {
//                viewStore.dispatch(ProductActions.loadProducts)
//            }
        }
    }
}

struct HomeViewState: Equatable {
    let isLoading: Bool
    let teaser: Teaser
}

#Preview {
    HomeView(store: StoreEnvironmentKey.defaultValue)
}
