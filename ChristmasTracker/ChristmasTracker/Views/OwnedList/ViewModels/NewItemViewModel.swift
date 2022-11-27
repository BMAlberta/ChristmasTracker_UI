//
//  NewItemViewModel.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 12/27/21.
//

import Foundation
import Combine

class NewItemViewModel: ObservableObject {
    
    @Published var newItem: NewItemModel = NewItemModel()
    @Published var isLoading = false
    @Published var isErrorState = false
    
    private var _session: SessionManaging
    private var _listInContext: String
    
    init(_ session: SessionManaging, listInContext: String) {
        self._session = session
        self._listInContext = listInContext
    }
    
    @MainActor
    func saveItem() async {
        self.isLoading = true
        do {
            let newListResponse: ListDetailResponse = try await ListServiceStore.addNewItem(toList: _listInContext, newItem: self.newItem)
            NotificationCenter.default.post(name: Notification.Name("newItemAdded"), object: nil, userInfo: ["updatedList": newListResponse.detail])
            self.isLoading = false
            self.isErrorState = false
        } catch {
            self.isLoading = false
            self.isErrorState = true
        }
    }
    
    func allRequiredFieldsPresent() -> Bool {
        
        let nums: Set<Character> = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]
        
        return !newItem.name.isEmpty
        && !newItem.description.isEmpty
        && !newItem.link.isEmpty
        && !newItem.price.isEmpty
        && !newItem.quantity.isEmpty
        && Set(newItem.quantity).isSubset(of: nums)
    }
}

