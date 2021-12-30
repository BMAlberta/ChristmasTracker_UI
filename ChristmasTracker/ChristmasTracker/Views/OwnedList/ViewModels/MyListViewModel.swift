//
//  MyListViewModel.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 12/27/21.
//

import Foundation
import Combine

class MyListViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var isErrorState = false
    @Published var items: [Item] = []
    
    private var _session: SessionManaging
    
    init(_ session: SessionManaging) {
        _session = session
    }
    
    @MainActor
    func fetchOwnedList() async {
        self.isLoading = true
        do {
            let ownedListResponse: AllItemsResponse = try await ListServiceStore.getOwnedItems(_session.token)
            self.items = ownedListResponse.items
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
        let item = self.items[index]
        
        do {
            self.isLoading = true
            let _: DeletedItemResponse = try await ListServiceStore.deleteItem(_session.token, item: item)
            let ownedListResponse: AllItemsResponse = try await ListServiceStore.getOwnedItems(_session.token)
            self.items = ownedListResponse.items
            self.isLoading = false
            self.isErrorState = false
        } catch {
            self.isLoading = false
            self.isErrorState = true
        }
    }
}

