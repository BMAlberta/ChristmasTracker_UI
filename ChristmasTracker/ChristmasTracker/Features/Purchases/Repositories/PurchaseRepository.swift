//
//  PurchaseRepository.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/16/26.
//

import Foundation

protocol PurchaseRepository: Repository {
    
    func fetchPurchases(itemId: String) async throws -> [Purchase]
    
    func createPurchase(itemId: String, _ request: CreatePurchaseRequest) async throws -> CreatePurchaseResponse
    
    func updatePurchase(id: String, _ request: UpdatePurchaseRequest) async throws -> Purchase
    
    func deletePurchase(id: String) async throws
}
