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
                    showingSessionExpiredAlert: appState.user.sessionInvalidated
                )
            }
        ))
    }
    
    var body: some View {
        if (!viewStore.state.isLoggedIn) {
            LoginView(store: store)
                .onAppear {
                    // Update viewStore to use environment store
                    updateViewStore()
                    viewStore.dispatch(UserActions.checkForBiometrics)
                }
                .alert("Session Expired", isPresented: .constant(viewStore.state.showingSessionExpiredAlert)) {
                    Button("OK") {
                        viewStore.dispatch(UserActions.loginErrorsCleared)
                    }
                } message: {
                    Text("Your session has expired and you have been logged out. Please log back in to continue.")
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
    let showingSessionExpiredAlert: Bool
}


#Preview {
    ContentView(store: StoreEnvironmentKey.defaultValue)
}

#Preview {
    ContentView(store: StoreEnvironmentKey.defaultValue)
        .preferredColorScheme(.dark)
}
