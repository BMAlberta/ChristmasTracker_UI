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
    
    init(_ session: SessionManaging, listInContext: String, baseModel: Item) {
        self._session = session
        self._listInContext = listInContext
        let model = NewItemModel()
        model.itemId = baseModel.id
        model.name = baseModel.name
        model.description = baseModel.description
        model.link = baseModel.link
        model.price = String(format: "%.2f", baseModel.price)
        model.quantity = String(baseModel.quantity)
        self.newItem = model
    }
    
    @MainActor
    func saveItem() async {
        self.isLoading = true
        do {
            self.trimPrice()
            let newListResponse: ListDetailResponse = try await ListServiceStore.addNewItem(toList: _listInContext, newItem: self.newItem)
            NotificationCenter.default.post(name: Notification.Name("newItemAdded"), object: nil, userInfo: ["updatedList": newListResponse.detail])
            self.isLoading = false
            self.isErrorState = false
        } catch {
            self.isLoading = false
            self.isErrorState = true
        }
    }
    
    @MainActor
    func updateItem() async {
        self.isLoading = true
        do {
            self.trimPrice()
            let updatedList: ListDetailResponse = try await ListServiceStore.updateItem(listContext: _listInContext, updatedItem: self.newItem)
            let extractedItem = Self.extractItemModel(listModel: updatedList, itemId: self.newItem.itemId)
            NotificationCenter.default.post(name: Notification.Name("newItemAdded"), object: nil, userInfo: ["updatedItem": extractedItem])
            self.isLoading = false
            self.isErrorState = false
        } catch {
            self.isLoading = false
            self.isErrorState = true
        }
    }
    
    private static func extractItemModel(listModel: ListDetailResponse, itemId: String) -> Item {
        
        let itemArray: [Item] = listModel.detail.items
        let item = itemArray.first(where: { $0.id == itemId })
        return item ?? Item()
    }
    
    private func trimPrice() {
        if self.newItem.price.hasPrefix("$") {
            let trimmed = self.newItem.price.dropFirst()
            self.newItem.price = String(trimmed)
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

