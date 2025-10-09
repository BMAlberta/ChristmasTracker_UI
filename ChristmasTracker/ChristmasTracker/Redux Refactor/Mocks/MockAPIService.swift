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
    
    init() {
        self.userAPI = MockUserAPIService()
        self.listAPI = MockListAPIService()
        self.itemAPI = MockItemAPIService()
        self.statsAPI = MockStatsAPIService()
    }
    
}

final class MockUserAPIService: UserDataProviding {
    func authenticateUser(_ credentials: Credentials) async throws -> LoginResponse {
        try await simulateNetworkDelay()
        return MockData.loggedInUser
    }
    
    func performLogout() async {
        return
    }
    
    func resetPassword(model: ChangePasswordModel) async throws -> PasswordResetResponse {
        try await simulateNetworkDelay()
        return PasswordResetResponse(userId: MockData.loggedInUser.userInfo)
    }
    
    func enrollWithAccessKey(_ model: AccessKeyEnrollmentModel) async throws -> EnrollmentStateResponse {
        try await simulateNetworkDelay()
        return EnrollmentStateResponse(success: true)
    }
    
    func getUserDetails(forId userId: String) async throws -> CurrentUserResponse {
        try await simulateNetworkDelay()
        return CurrentUserResponse(user: MockData.userModel)
    }
    
    
}

final class MockListAPIService: ListDataProviding {
    func getHomeFeed() async throws -> HomeFeedResponse {
        try await simulateNetworkDelay()
        return MockData.homeOverview
    }
    
    func getOwnedItems() async throws -> OwnedListResponse {
        try await simulateNetworkDelay()
        return MockData.ownedLists
    }
    
    func getListOverviewByUser() async throws -> ListOverviewResponse {
        try await simulateNetworkDelay()
        return MockData.listOverview
    }
    
    func getList(listId: String) async throws -> ListDetailResponse {
        try await simulateNetworkDelay()
        return MockData.listDetail
    }
    
    func createList(newList: String) async throws -> ListDetailResponse {
        try await simulateNetworkDelay()
        return MockData.listDetail
    }
    
    func deleteList(listId: String) async throws {
        try await simulateNetworkDelay()
        return
    }
    
    
}

final class MockItemAPIService: ItemDataProviding {
    func addNewItem(toList listInContext: String, newItem: NewItemModel) async throws -> ListDetailResponse {
        try await simulateNetworkDelay()
        return MockData.listDetail
    }
    
    func markItemPurchased(listId: String, itemInContext: Item, quantity: Int) async throws -> ListDetailResponse {
        try await simulateNetworkDelay()
        return MockData.listDetail
    }
    
    func markItemRetracted(listId: String, itemInContext: Item) async throws -> ListDetailResponse {
        try await simulateNetworkDelay()
        return MockData.listDetail
    }
    
    func updateItem(listInContext: String, updatedItem: NewItemModel) async throws -> ListDetailResponse {
        try await simulateNetworkDelay()
        return MockData.listDetail
    }
    
    func deleteItem(fromList listId: String, item: Item) async throws {
        try await simulateNetworkDelay()
        return
    }
    
    
}

final class MockStatsAPIService: StatsDataProviding {
    func getPurchaseStats() async throws -> PurchaseStatsResponse {
        try await simulateNetworkDelay()
        return MockData.stats
    }
    
}

fileprivate func simulateNetworkDelay() async throws {
    try await Task.sleep(nanoseconds: UInt64(1.0 * 1_000_000_000))
}
