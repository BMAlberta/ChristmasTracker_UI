//
//  ListAPIService.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 10/1/25.
//

import Foundation

protocol ListDataProviding {
    func getOwnedItems() async throws -> OwnedListResponse
    func getListOverviewByUser() async throws -> ListOverviewResponse
    func getList(listId: String) async throws -> ListDetailResponse
    func createList(newList: String) async throws -> ListDetailResponse
    func deleteList(listId: String) async throws
    func getHomeFeed() async throws -> HomeFeedResponse
}


actor ListAPIService: ListDataProviding {
    func getHomeFeed() async throws -> HomeFeedResponse {
        return MockData.homeOverview
    }
    
    func getOwnedItems() async throws -> OwnedListResponse {
        let foo = OwnedListModel(name: "Foo",
                                 members: ["Bar"],
                                 id: "1234",
                                 creationDate: "123",
                                 lastUpdateDate: "123")
        
        return OwnedListResponse(ownedLists:[foo])
    }
    
    func getListOverviewByUser() async throws -> ListOverviewResponse {
        return ListOverviewResponse(listOverviews: [ListOverviewDetails(listName: "Foo", totalItems: "1", purchasedItems: "1", id: "123", lastUpdate: "123", listStatus: .active, ownerInfo: SlimUserModel(), members: [MemberDetail(firstName: "Foo", lastName: "Foo", userId: "Foo")])])
    }
    
    func getList(listId: String) async throws -> ListDetailResponse {
        return ListDetailResponse(detail: ListDetailModel(name: "Foo",
                                                          owner: "Foo",
                                                          members: ["Foo"],
                                                          id: "Foo",
                                                          creationDate: "123",
                                                          lastUpdateDate: "123",
                                                          status: .active,
                                                          items: [], __v: 1))
    }
    
    func createList(newList: String) async throws -> ListDetailResponse {
        return ListDetailResponse(detail: ListDetailModel(name: "Foo",
                                                          owner: "Foo",
                                                          members: ["Foo"],
                                                          id: "Foo",
                                                          creationDate: "123",
                                                          lastUpdateDate: "123",
                                                          status: .active,
                                                          items: [],
                                                          __v: 1))
    }
    
    func deleteList(listId: String) async throws {
        
    }
    
    
}
