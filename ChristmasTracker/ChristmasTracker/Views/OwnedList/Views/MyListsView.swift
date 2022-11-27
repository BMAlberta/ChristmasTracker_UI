//
//  MyListView.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 1/18/21.
//

import SwiftUI

struct MyListsView: View {
    @EnvironmentObject var _session: UserSession
    @StateObject var viewModel: MyListsViewModel
    @State var showingNewListFlow = false
    @State var newListName: String = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                List {
                    ForEach(viewModel.activeLists, id: \.id) { i in
                        NavigationLink(destination: LazyView(ListDetailView(viewModel: ListDetailViewModel(_session, listId: i.id, displayName: i.name, ownedList: true)))) {
                            OwnedListOverviewView(data: i)
                        }
                    }
                    .onDelete(perform: delete)
                }
                .navigationBarItems(trailing: addItemButton)
                .navigationBarTitle("My Lists")
                
                if (viewModel.isLoading) {
                    ProgressView()
                }
            }
        }
        .navigationViewStyle(.stack)
        .onAppear {
            Task {
                if _session.sessionActive {
                    await self.viewModel.fetchOwnedList()
                }
            }
        }
        .refreshable {
            await self.viewModel.fetchOwnedList()
        }
        .alert(isPresented: $viewModel.isErrorState) {
            Alert(title: Text("Request Failed"), message: Text("Unable to process your request. Please try again."), dismissButton: .default(Text("Ok")))
        }
    }
    
    private func delete(at offsets: IndexSet) {
        Task() {
            await self.viewModel.deleteItem(at: offsets)
        }
    }
    
    private var addItemButton: some View {
        Button(action: {
            self.showingNewListFlow.toggle()
        }) {
            Image(systemName: "plus")
        }
        .alert("New List", isPresented: $showingNewListFlow, actions: {
            TextField("List Name", text: $newListName)
            
            Button("Save", action: {
                Task {
                    await self.viewModel.createNewList(newListName: newListName)
                    $newListName.wrappedValue = ""
                }
            })
            Button("Cancel", role: .cancel, action: {
                $newListName.wrappedValue = ""
            })
        }, message: {
            Text("Please enter the name for the new list.")
        })
    }
}

struct OwnedListOverviewView: View {
    let data: OwnedListModel
    
    var body: some View {
            Spacer()
            VStack(alignment: .leading) {
                Text("\(data.name)")
                    .font(.title2)
                Text("Last Update: \(FormatUtility.convertDateStringToHumanReadable(rawDate: data.lastUpdateDate))")
                    .font(.caption)
                Text("Created on: \(FormatUtility.convertDateStringToHumanReadable(rawDate: data.creationDate))")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            Spacer()
    }
}
