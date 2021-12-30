//
//  MyListView.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 1/18/21.
//

import SwiftUI

struct MyListView: View {
    @EnvironmentObject var _session: UserSession
    @StateObject var viewModel: MyListViewModel
    @State var showingDetail = false
    
    var body: some View {
        NavigationView {
            ZStack {
                List {
                    ForEach(viewModel.items, id: \.id) { i in
                        NavigationLink(destination: LazyView(ItemDetailView(viewModel: ItemDetailViewModel(_session, itemModel: i)))) {
                            ListItemView(data: i)
                        }
                    }
                    .onDelete(perform: delete)
                }
                .navigationBarItems(trailing: addItemButton)
                .navigationBarTitle("My Items")
                
                if (viewModel.isLoading) {
                    ProgressView()
                }
            }
        }
        .navigationViewStyle(.stack)
        .onAppear {
            Task {
                await self.viewModel.fetchOwnedList()
            }
        }
        .refreshable {
            await self.viewModel.fetchOwnedList()
        }
    }
    
    private func delete(at offsets: IndexSet) {
        Task() {
            await self.viewModel.deleteItem(at: offsets)
        }    }
    
    private var addItemButton: some View {
        Button(action: {
            self.showingDetail.toggle()
        }) {
            Image(systemName: "plus")
        }.sheet(isPresented: $showingDetail) {
            let newItemViewModel = NewItemViewModel(_session)
            NewItemView(viewModel: newItemViewModel, showingModal: $showingDetail)
            EmptyView()
        }
    }
}
