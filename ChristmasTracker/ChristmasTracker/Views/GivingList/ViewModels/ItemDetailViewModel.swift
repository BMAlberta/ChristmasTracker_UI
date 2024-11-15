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
    @Published var isDeleteSuccessful = false
    @Published var itemModel: Item = Item()
    @Published var listInfo: ListInfo
    
    var shouldShowEducationPopover: Bool {
        return EducationUtility.educationModelCanBeShown(educationModel: self.educationModel)
    }
    
    var educationModel: EducationModel {
        return EducationModel(educationId: "EditFeature_Intro",
                              educationTitle: "What's this?",
                              educationDescription: "You can now easily edit items that you have previously created. All fields are editable but, please note, that this item may have been purchased and the purchasers will not be made aware of any changes.")
    }
    
    
    private var _session: UserSession
    
    init(_ session: UserSession, listInfo: ListInfo, itemModel: Item) {
        _session = session
        self.itemModel = itemModel
        self.listInfo = listInfo
        NotificationCenter.default.addObserver(self, selector: #selector(respondToNotification), name: Notification.Name("newItemAdded"), object: nil)
    }
    
    
    @objc func respondToNotification(_ notification: Notification) {
        guard let userInfo = notification.userInfo, let itemModel = userInfo["updatedItem"] as? Item else {
            return
        }
        
        updateModel(model: itemModel)
    }
    
    func updateModel(model: Item) {
        guard self.itemModel.id == model.id else {
            return
        }
        self.itemModel = model
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
    
    func performAction(_ action: ActionButtonType, quantity: String?) async {
        switch action {
        case .purchase:
            await self.purchaseItem(quantity: quantity)
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
            let _ = try await ListServiceStore.deleteItem(fromList: listInfo.listId, item: itemModel)
            NotificationCenter.default.post(name: Notification.Name("itemDeleted"), object: nil)
            self.isLoading = false
            self.isErrorState = false
            self.isDeleteSuccessful = true
        } catch {
            self.isLoading = false
            self.isErrorState = true
            self.isDeleteSuccessful = false
        }
    }
    
    @MainActor
    private func purchaseItem(quantity: String? = nil) async {

        var quantityToPurchase = 0
        if let requestedQuantity = quantity {
            quantityToPurchase = Int(requestedQuantity) ?? 0
        } else {
            quantityToPurchase = self.itemModel.quantity
        }
        
        self.isLoading = true
        do {
            let purchaseResponse = try await ListServiceStore.markItemPurchased(listId: self.listInfo.listId, itemInContext: self.itemModel, quantity: quantityToPurchase)
            let extractedItem = Self.extractItemModel(listModel: purchaseResponse, itemId: self.itemModel.id)
            self.itemModel = extractedItem
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
            NotificationCenter.default.post(name: Notification.Name("purchaseStatusChanged"), object: nil)
        } catch {
            self.isLoading = false
            self.isErrorState = true
            self.isPurchaseSuccessful = false
        }
    }
    
}
