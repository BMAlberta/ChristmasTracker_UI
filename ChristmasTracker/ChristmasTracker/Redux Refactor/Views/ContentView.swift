//
//  ContentView.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 10/4/25.
//

import SwiftUI

struct ContentView: View {
    private var store: Store<AppState>
    @StateObject private var viewStore: ViewStore<ContentViewState>
    
    
    init(store: Store<AppState>) {
        self.store = store
        self._viewStore = StateObject(wrappedValue: ViewStore(
            store: store,
            observe: { appState in
                ContentViewState(
                    currentTab: appState.ui.currentTab,
                    isLoggedIn: appState.user.isLoggedIn,
                )
            }
        ))
    }
    
    var body: some View {
        if (!viewStore.state.isLoggedIn) {
            LoginView_Redux(store: store)
                .onAppear {
                    // Update viewStore to use environment store
                    updateViewStore()
                }
        } else {
            DashboardView(store: store)
        }
    }
    
    private func updateViewStore() {
        viewStore.updateStore(store)
    }
}

struct ContentViewState: Equatable {
    let currentTab: AppTab
    let isLoggedIn: Bool
}


#Preview {
    ContentView(store: StoreEnvironmentKey.defaultValue)
}
