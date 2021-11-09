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
                List {
                    ForEach(_store.state.ownedList.items, id: \.id) { i in
                        NavigationLink(destination: LazyView(ItemDetailView(model: i))) {
                            ListItemView(data: i)
                        }
                    }
                    .onDelete(perform: delete)
                }
                .navigationBarItems(trailing: addItemButton)
                .navigationBarTitle("My Items")
                
                if (_store.state.ownedList.fetchInProgess) {
                    ProgressView()
                }
            }
        }
        .navigationViewStyle(.stack)
        .onAppear {
            let token = _store.state.auth.token
            _store.dispatch(.list(action: .fetchOwnedList(token: token)))
        }
    }
    
    private func delete(at offsets: IndexSet) {
        let index = offsets[offsets.startIndex]
        let item = _store.state.ownedList.items[index]
        _store.dispatch(.list(action: .deleteItem(token: _store.state.auth.token, item: item)))
    }
    
    private var addItemButton: some View {
        Button(action: {
            self.showingDetail.toggle()
        }) {
            Image(systemName: "plus")
        }.sheet(isPresented: $showingDetail) {
            NewItemView(showingModal: $showingDetail)
            EmptyView()
        }
    }
}
