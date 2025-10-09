//
//  MockData.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 10/4/25.
//

import Foundation

struct MockData {
    static let loggedInUser = LoginResponse(userInfo: "fake-uuid-for-mock-user")
    static let userModel = UserModel()
    static let listDetail = ListDetailResponse(detail: ListDetailModel(name: "Foo",
                                                                       owner: "Foo",
                                                                       members: ["Foo"],
                                                                       id: "Foo",
                                                                       creationDate: "123",
                                                                       lastUpdateDate: "123",
                                                                       status: .active,
                                                                       items: [], __v: 1))
    static let listOverview = ListOverviewResponse(listOverviews: [
        ListOverviewDetails(listName: "Foo",
                            totalItems: "1",
                            purchasedItems: "1",
                            id: "123",
                            lastUpdate: "123",
                            listStatus: .active,
                            ownerInfo: SlimUserModel(),
                            members: [
                                MemberDetail(firstName: "Foo", lastName: "Foo", userId: "Foo")
                            ])
    ])
    
    static let ownedLists = OwnedListResponse(ownedLists:
                                                [OwnedListModel(name: "Foo",
                                                                members: ["fo"],
                                                                id: "Mock",
                                                                creationDate: "",
                                                                lastUpdateDate: "")
                                                ])
    static let stats = PurchaseStatsResponse(purchaseStats: [PurchaseStat()])
    
    static let homeOverview = HomeFeedResponse(feed: HomeOverview(
        listSummaries: [
            ListSummary(
                id: "12",
                name: "Sample overview",
                owner: LWUserModel(
                    id: "123",
                    firstName: "John",
                    lastName: "Doe"),
                status: .active,
                creationDate: "2025-10-04",
                lastUpdateDate: "2025-10-04",
                totalItems: 10,
                purchasedItems: 2,
                members: [LWUserModel(
                    id: "234",
                    firstName: "Jane",
                    lastName: "Doe")]),
            ListSummary(
                id: "23",
                name: "Sample Xmas List",
                owner: LWUserModel(
                    id: "234",
                    firstName: "Jane",
                    lastName: "Doe"),
                status: .active,
                creationDate: "2025-10-04",
                lastUpdateDate: "2025-10-04",
                totalItems: 5,
                purchasedItems: 2,
                members: [LWUserModel(
                    id: "123",
                    firstName: "John",
                    lastName: "Doe")])
        ],
        recentActivity: [
            ActivityItem(id: "4",
                         type: .listAddition,
                         owner: LWUserModel(
                            id: "123",
                            firstName: "John",
                            lastName: "Doe"),
                         date: "2025-10-04",
                         primaryDataPoint: "New List",
                         secondaryDataPoint: "New List"),
            ActivityItem(id: "5",
                         type: .listAddition,
                         owner: LWUserModel(
                            id: "123",
                            firstName: "John",
                            lastName: "Doe"),
                         date: "2025-10-04",
                         primaryDataPoint: "Another List",
                         secondaryDataPoint: "Yet Another List")
        ]))
}
