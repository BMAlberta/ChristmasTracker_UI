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
    @State private var isDetailPresented = false
    @State var selectedItem: Item?
    var body: some View {
        List {
            ForEach(_store.state.ownedList.userItems, id: \.id) { i in
                ListItemView(data: i, hidePurchase: false)
                    .onTapGesture {
                        selectedItem = i
                        isDetailPresented = true
                    }
            }
            .navigationViewStyle(.stack)
            .navigationTitle("\(user.firstName)'s List")
        }
        .sheet(item: $selectedItem, onDismiss: {
            _store.state.ownedList.purchaseComplete = false
            isDetailPresented = false
        }, content: { item in
            LazyView(ItemDetailView(model: item))
        })
        .onAppear {
            let token = _store.state.auth.token
            _store.dispatch(.list(action: .fetchUserList(token: token, userId: user.rawId)))
        }
    }
}

struct ListDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let store = AppStore(initialState: .init(
            authState: AuthState(),
            listState: ListState()
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


