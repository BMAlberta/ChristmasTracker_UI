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
    
    init(_ session: SessionManaging) {
        self._session = session
    }
    
    @MainActor
    func saveItem() async {
        self.isLoading = true
        do {
            let _ : NewItemResponse = try await ListServiceStore.addNewItem(token: _session.token, newItem: self.newItem)
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

