//
//  ListDetailView.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 10/5/21.
//

import SwiftUI

struct ListDetailView: View {
    @EnvironmentObject var _store: AppStore
    var user: SlimUser
    var body: some View {
        NavigationView {
            List(_store.state.ownedList.items) { i in
                NavigationLink(destination: LazyView(EmptyView())) {
                    ListItemView(data: i, hidePurchase: false)
                }
            }
        }.onAppear {
            let token = _store.state.auth.token
            _store.dispatch(.list(action: .fetchUserList(token: token, userId: user.rawId)))
        }
        .navigationTitle("\(user.firstName)'s List")
        
    }
}

struct ListDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let store = AppStore(initialState: .init(
            auth: AuthState(),
            ownedList: ListState()
        ),
        reducer: appReducer,
        middlewares: [
            authMiddleware(service: AuthService()),
            logMiddleware(),
            listMiddleware(service: ListService())
        ])
        let user = SlimUser(firstName: "Brian", lastName: "Alberta", rawId: "615d0aca9dce0250b0eac9c2")
        ListDetailView(user: user).environmentObject(store)
    }
}


