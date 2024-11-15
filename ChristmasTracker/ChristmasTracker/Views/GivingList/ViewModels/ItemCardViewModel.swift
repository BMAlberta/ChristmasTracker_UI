//
//  ItemCardViewModel.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 11/13/22.
//


import Foundation
import Combine

class ItemCardViewModel: ObservableObject {
    
    enum ActionButtonType {
        case purchase
        case retract
        case delete
    }
    
    @Published var isLoading = false
    @Published var isErrorState = false
    @Published var isPurchaseSuccessful = false
    @Published var itemModel: Item
    @Published var listId: String
    
    private var _session: UserSession
    
    init(_ session: UserSession, listContext: String, itemInContext: Item) {
        _session = session
        self.listId = listContext
        self.itemModel = itemInContext
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
            self.isErrorState = false
        }
    }
    
    @MainActor
    private func purchaseItem(quantity: String? = nil) async {
        self.isLoading = true
        
        var quantityToPurchase = 0
        if let requestedQuantity = quantity {
            quantityToPurchase = Int(requestedQuantity) ?? 0
        } else {
            quantityToPurchase = self.itemModel.quantity
        }
        do {
            let _ = try await ListServiceStore.markItemPurchased(listId: listId, itemInContext: itemModel, quantity: quantityToPurchase)
//            self.itemModel = purchaseResponse.updatedItem
            self.isLoading = false
            self.isErrorState = false
            self.isPurchaseSuccessful = true
            NotificationCenter.default.post(name: Notification.Name("purchaseStatusChanged"), object: nil)
        } catch {
            self.isLoading = false
            self.isErrorState = true
            self.isPurchaseSuccessful = false
        }
    }
    
    @MainActor
    private func retractPurchase() async {
        self.isLoading = true
        do {
            let _ = try await ListServiceStore.markItemRetracted(listId: listId, itemInContext: itemModel)
//            self.itemModel = retractedResponse.updatedItem
            self.isLoading = false
            self.isErrorState = false
            self.isPurchaseSuccessful = true
            NotificationCenter.default.post(name: Notification.Name("purchaseStatusChanged"), object: nil)
        } catch {
            self.isLoading = false
            self.isErrorState = true
            self.isPurchaseSuccessful = false
        }
    }
}

