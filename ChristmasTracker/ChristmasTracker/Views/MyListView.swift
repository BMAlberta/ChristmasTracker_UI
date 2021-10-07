//
//  MyListView.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 1/18/21.
//

import SwiftUI

struct MyListView: View {
    @EnvironmentObject var _store: AppStore
    @State var showingDetail = false
    
    var body: some View {
        NavigationView {
            ZStack {
                List(_store.state.ownedList.items) { i in
                    NavigationLink(destination: LazyView(EmptyView())) {
                        ListItemView(data: i)
                    }
                }
                .navigationBarItems(trailing: addItemButton)
                .navigationBarTitle("My Items")
                
                if (_store.state.ownedList.fetchInProgess) {
                    ProgressView()
                }
            }
        }.onAppear {
            let token = _store.state.auth.token
            _store.dispatch(.list(action: .fetchOwnedList(token: token)))
        }
    }
    
    
    private var addButton: some View {
        return AnyView(Button(action: onAdd) { Image(systemName: "plus") })
    }
    
    private var addItemButton: some View {
        Button(action: {
            self.showingDetail.toggle()
            onAdd()
        }) {
            Image(systemName: "plus")
        }.sheet(isPresented: $showingDetail) {
            NewItemView(showingModal: $showingDetail)
            EmptyView()
        }
    }
    
    func onAdd() {
        // To be implemented in the next section
        print("Add button pressed")
    }
}
