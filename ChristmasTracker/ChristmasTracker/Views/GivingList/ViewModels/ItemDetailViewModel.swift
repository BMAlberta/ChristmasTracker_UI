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
    
    private var _session: UserSession
    
    init(_ session: UserSession, itemModel: Item) {
        _session = session
        self.itemModel = itemModel
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
            let _ = try await ListServiceStore.deleteItem(_session.token, item: self.itemModel)
            self.isLoading = false
            self.isErrorState = false
        } catch {
            self.isLoading = false
            self.isErrorState = false
        }
    }
    
    @MainActor
    private func purchaseItem() async {
        self.isLoading = true
        do {
            let purchaseResponse = try await ListServiceStore.markItemPurchased(token: _session.token, item: self.itemModel)
            self.itemModel = purchaseResponse.updatedItem
            self.isLoading = false
            self.isErrorState = false
            self.isPurchaseSuccessful = true
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
            let retractedResponse = try await ListServiceStore.markItemRetracted(_session.token, item: self.itemModel)
            self.itemModel = retractedResponse.updatedItem
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
