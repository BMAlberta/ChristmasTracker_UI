//
//  ItemDetailViewModel.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 12/5/21.
//

import Foundation
import Combine

class ItemDetailViewModel: ObservableObject {
    
    enum ActionButtonType {
        case purchase
        case retract
        case delete
    }
    @Published var isLoading = false
    @Published var isErrorState = false
    @Published var isPurchaseSuccessful = false
    @Published var itemModel: Item = Item()
    @Published var listInfo: ListInfo
    
    
    private var _session: UserSession
    
    init(_ session: UserSession, listInfo: ListInfo, itemModel: Item) {
        _session = session
        self.itemModel = itemModel
        self.listInfo = listInfo
    }
    
    
    func performAction(_ action: ActionButtonType) async {
        switch action {
        case .purchase:
            await self.purchaseItem()
        case .retract:
            await  self.retractPurchase()
        case .delete:
            await self.deleteItem()
        }
    }
    
    @MainActor
    private func deleteItem() async {
        self.isLoading = true
        do {
            let _ = try await ListServiceStore.deleteItem(fromList: "", item: itemModel)
            self.isLoading = false
            self.isErrorState = false
        } catch {
            self.isLoading = false
            self.isErrorState = true
        }
    }
    
    @MainActor
    private func purchaseItem() async {
        self.isLoading = true
        do {
            
            let purchaseResponse = try await ListServiceStore.markItemPurchased(listId: self.listInfo.listId, itemInContext: self.itemModel)
            let extractedItem = Self.extractItemModel(listModel: purchaseResponse, itemId: self.itemModel.id)
            self.itemModel = extractedItem
            self.isLoading = false
            self.isErrorState = false
            self.isPurchaseSuccessful = true
        } catch {
            self.isLoading = false
            self.isErrorState = true
            self.isPurchaseSuccessful = false
        }
    }
    
    private static func extractItemModel(listModel: ListDetailResponse, itemId: String) -> Item {
        
        let itemArray: [Item] = listModel.detail.items
        let item = itemArray.first(where: { $0.id == itemId })
        return item ?? Item()
    }
    
    @MainActor
    private func retractPurchase() async {
        self.isLoading = true
        do {
            let retractedResponse = try await ListServiceStore.markItemRetracted(listId: self.listInfo.listId, itemInContext: self.itemModel)
            let extractedItem = Self.extractItemModel(listModel: retractedResponse, itemId: self.itemModel.id)
            self.itemModel = extractedItem
            self.isLoading = false
            self.isErrorState = false
            self.isPurchaseSuccessful = true
        } catch {
            self.isLoading = false
            self.isErrorState = true
            self.isPurchaseSuccessful = false
        }
    }
}
