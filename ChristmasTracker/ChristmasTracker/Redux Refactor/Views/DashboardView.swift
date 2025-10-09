//
//  DashboardView.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 10/4/25.
//

import SwiftUI

struct DashboardView: View {
    private var store: Store<AppState>
    @StateObject private var viewStore: ViewStore<DashboardViewState>
    
    @State private var email = ""
    @State private var password = ""
    @State private var isRegistering = false
    
    init(store: Store<AppState>) {
        self.store = store
        self._viewStore = StateObject(wrappedValue: ViewStore(
            store: store,
            observe: { appState in
                DashboardViewState(
                    currentTab: store.state.ui.currentTab
                )
            }
        ))
    }
 
    var body: some View {
        TabView(selection: Binding(
            get: { viewStore.state.currentTab },
            set: { viewStore.dispatch(UIActions.setCurrentTab($0)) }
        )) {
            
            HomeView(store: store)
                .tabItem {
                    Image(systemName: AppTab.home.iconName)
                    Text(AppTab.home.rawValue)
                }
                .tag(AppTab.home)
            ListsView()
                .tabItem {
                    Image(systemName: AppTab.lists.iconName)
                    Text(AppTab.lists.rawValue)
                }
                .tag(AppTab.lists)
            StatsView_Redux()
                .tabItem {
                    Image(systemName: AppTab.stats.iconName)
                    Text(AppTab.stats.rawValue)
                }
                .tag(AppTab.stats)
            ProfileView_Redux()
                .tabItem {
                    Image(systemName: AppTab.profile.iconName)
                    Text(AppTab.profile.rawValue)
                }
                .tag(AppTab.profile)
        }
        .overlay(alignment: .top) {
//            if let toast = viewStore.state.toast {
//                ToastView(message: toast)
//                    .onAppear {
//                        DispatchQueue.main.asyncAfter(deadline: .now() + toast.duration) {
//                            viewStore.dispatch(UIActions.hideToast)
//                        }
//                    }
//            }
        }
        .onAppear {
//            viewStore.dispatch(UIActions.checkForUpdate)
        }
    }
}

struct DashboardViewState: Equatable {
    var currentTab: AppTab
}

#Preview {
    DashboardView(store: StoreEnvironmentKey.defaultValue)
}
