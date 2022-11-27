//
//  MyListViewModel.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 12/27/21.
//

import Foundation
import Combine

class MyListsViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var isErrorState = false
    @Published var activeLists: [OwnedListModel] = []
    @Published var items: [Item] = []
    @Published var newListName: String = ""
    
    private var _session: SessionManaging
    
    init(_ session: SessionManaging) {
        _session = session
    }
    
    @MainActor
    func fetchOwnedList() async {
        self.isLoading = true
        do {
            let ownedListResponse: OwnedListResponse = try await ListServiceStore.getOwnedItems()
            self.activeLists = ownedListResponse.ownedLists
            self.isLoading = false
            self.isErrorState = false
        } catch {
            self.isLoading = false
            self.isErrorState = false
        }
    }
    
    @MainActor
    func deleteItem(at offsets: IndexSet) async {
        let index = offsets[offsets.startIndex]
        let listInContext = self.activeLists[index]
        
        do {
            self.isLoading = true
            let _ = try await ListServiceStore.deleteList(listId: listInContext.id)
            let ownedListResponse: OwnedListResponse = try await ListServiceStore.getOwnedItems()
            self.activeLists = ownedListResponse.ownedLists
            self.isLoading = false
            self.isErrorState = false
        } catch {
            self.isLoading = false
            self.isErrorState = true
        }
    }
    
    @MainActor
    func createNewList(newListName: String) async {
        self.isLoading = true
        do {
            let _: ListDetailResponse = try await ListServiceStore.addNewList(newList: newListName)
            NotificationCenter.default.post(name: Notification.Name("newItemAdded"), object: nil, userInfo: nil)
            await self.fetchOwnedList()
        } catch {
            self.isLoading = false
            self.isErrorState = true
        }
    }
}

