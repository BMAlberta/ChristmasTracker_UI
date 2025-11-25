//
//  MockAPIService.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 10/4/25.
//

import Foundation


final class MockAPIService: APIServiceProviding {
    var userAPI: any UserDataProviding
    var listAPI: any ListDataProviding
    var itemAPI: any ItemDataProviding
    var statsAPI: any StatsDataProviding
    var updateAPI: any UpdateDataProviding
    
    init() {
        self.userAPI = MockUserAPIService()
        self.listAPI = MockListAPIService()
        self.itemAPI = MockItemAPIService()
        self.statsAPI = MockStatsAPIService()
        self.updateAPI = MockUpdateAPIService()
    }
    
}

final class MockUserAPIService: UserDataProviding {
    func fetchUserMetadata() async throws -> UserMetadataResponse {
        try await simulateNetworkDelay()
        return MockData.userMetadata
    }
    
    func updateProfileName(userId: String, firstName: String, lastName: String) async throws -> UpdateProfileResponse {
        try await simulateNetworkDelay()
        return MockData.updateProfile
    }
    
    func authenticateUser(_ credentials: Credentials) async throws -> AuthResponse {
        try await simulateNetworkDelay()
        return MockData.loggedInUser
    }
    
    func performLogout() async throws {
        try await simulateNetworkDelay()
        return
    }
    
    func enrollWithAccessKey(_ model: AccessKeyEnrollmentModel) async throws {
        try await simulateNetworkDelay()
        return
    }
    
    func updatePassword(oldPassword: String, newPassword: String) async throws -> ChangePasswordResponse {
        try await simulateNetworkDelay()
        return MockData.updatePassword
    }
    
    
}

final class MockListAPIService: ListDataProviding {
//    func getHomeFeed() async throws -> HomeFeedResponse {
//        try await simulateNetworkDelay()
//        return HomeFeedResponse(feed:MockData.homeOverview)
//    }
    
    func getHomeFeed() async throws -> AppDataResponse {
        try await simulateNetworkDelay()
        var mockData = MockData.appDataResponse
        
        mockData.appData.listOverviews[1].totalItems = Int.random(in: 1...100)
        mockData.appData.listOverviews[1].purchasedItems = Int.random(in: 100...110)
        mockData.appData.listOverviews[1].items[0].quantity = Int.random(in: 1...10)
        mockData.appData.listOverviews[1].items[0].purchaseState = PurchaseState.allCases[Int.random(in: 0..<PurchaseState.allCases.count)]
        
        return mockData
    }
    
    func createList(newList: NewListDetails) async throws -> AddListResponse {
        try await simulateNetworkDelay()
        return MockData.addList
    }
    
    func deleteList(listId: String) async throws {
        try await simulateNetworkDelay()
        return
    }
}

final class MockItemAPIService: ItemDataProviding {
    func markItemRetracted(listId: String, itemId: String) async throws {
        try await simulateNetworkDelay()
        return
    }
    
    func markItemPurchased(listId: String, itemInContext: String, quantityPurchased: Int, purchasePrice: Double) async throws -> ItemPurchaseResponse {
        try await simulateNetworkDelay()
        return MockData.itemPurchase
    }
    
    func addNewItem(toList listInContext: String, newItem: NewItemDetails) async throws -> AddItemResponse {
        try await simulateNetworkDelay()
        return MockData.addItem
    }
    
    func updateItem(listInContext: String, updatedItem: NewItemDetails) async throws -> AddItemResponse {
        try await simulateNetworkDelay()
        return MockData.addItem
    }
    
    func deleteItem(listId: String, itemId: String) async throws {
        try await simulateNetworkDelay()
        return
    }
}

final class MockUpdateAPIService: UpdateDataProviding {
    func fetchUpdateInfo() async throws -> UpdateInfoModelResponse {
        try await simulateNetworkDelay()
        return MockData.updateResponse
    }
}

final class MockStatsAPIService: StatsDataProviding {
    func getPurchaseStats() async throws -> PurchaseStatsResponse {
        try await simulateNetworkDelay()
        return MockData.stats
    }
}

fileprivate func simulateNetworkDelay() async throws {
    let randomPause = Double(Int.random(in: 1..<100))
    let doublePause = randomPause/100.0
    print("XXXX: Simulating network delay of \(doublePause) seconds")
    try await Task.sleep(nanoseconds: UInt64(doublePause * 1_000_000_000))
}
