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
    @State private var deleteAlertPresented = false
    @State private var selectedItemOffest = IndexSet()
    
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
            .alert(isPresented: $deleteAlertPresented) {
                Alert(
                    title: Text("Are you sure?"),
                    message: Text("Are you sure you want to delete this list? Deleted lists cannot be recovered."),
                    primaryButton: .destructive(Text("Yes, Delete")) {
                        $deleteAlertPresented.wrappedValue.toggle()
                        Task() {
                            await self.viewModel.deleteItem(at: self.selectedItemOffest)
                        }
                    },
                    secondaryButton: .cancel()
                )
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
        self.$selectedItemOffest.wrappedValue = offsets
        self.$deleteAlertPresented.wrappedValue = true
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
