//
//  Dashboard.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 1/18/21.
//

import SwiftUI

struct Dashboard: View {
    @EnvironmentObject var _store: AppStore
    
    var body: some View {
        if (_store.state.auth.isLoggedIn) {
            TabView {
                MyListView().environmentObject(_store)
                    .tabItem {
                        Image(systemName: "list.dash")
                        Text("My List")
                    }
                GivingListView().environmentObject(_store)
                    .tabItem {
                        Image(systemName: "books.vertical")
                        Text("Giving")
                    }
                ProfileView().environmentObject(_store)
                    .tabItem {
                        Image(systemName: "person.crop.circle")
                        Text("Profile")
                    }
            }
            .onAppear(perform: {
                _store.dispatch(.auth(action: .fetchCurrenUser(token: _store.state.auth.token)))
            })
        } else {
            EmptyView()
        }
    }
}

struct Dashboard_Previews: PreviewProvider {
    static var previews: some View {
        Dashboard()
    }
}
