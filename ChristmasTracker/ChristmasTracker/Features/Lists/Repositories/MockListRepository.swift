//
//  MockListRepository.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/13/26.
//

import Foundation

actor MockListRepository: ListRepository {
    
    // MARK: - Mock Data Storage
    private var lists: [ListDetail] = []
    private var nextId = 1
    
    // MARK: - Configuration
    var shouldFail: Bool = false
    var delay: TimeInterval = 0.5
    
    // MARK: - Initialization
    init(withMockData: Bool = true) {
        if withMockData {
            lists = MockListData.allLists
        }
    }
    
    // MARK: - List Repository
    
    func fetchLists() async throws -> [GiftList] {
        LogDebug("Mock fetchLists", category: .business)
        
        try await Task.sleep(for: .seconds(delay))
        
        if shouldFail {
            throw ListError.fetchFailed
        }
        
        return lists.map { detail in
            GiftList(
                id: detail.id,
                name: detail.name,
                theme: detail.theme,
                year: detail.year,
                visibility: detail.visibility,
                status: detail.status,
                recipient: detail.recipient,
                owner: detail.owner,
                coOwner: detail.coOwner,
                myRole: detail.myRole,
                itemCount: detail.itemCount,
                purchasedCount: detail.purchasedCount,
                createdAt: detail.createdAt,
                updatedAt: detail.updatedAt
            )
        }
    }
    
    func fetchListDetail(id: String) async throws -> ListDetail {
        LogDebug("Mock fetchList for id: \(id)", category: .business)
        
        try await Task.sleep(for: .seconds(delay))
        
        if shouldFail {
            throw ListError.fetchFailed
        }
        
        guard let list = lists.first(where: { $0.id == id }) else {
            throw ListError.notFound
        }
        
        return list
    }
    
    func createList(_ request: CreateListRequest) async throws -> ListDetail {
        LogDebug("Mock createList", category: .business)
        
        try await Task.sleep(for: .seconds(delay))
        
        if shouldFail {
            throw ListError.createFailed
        }
        
        let newList = ListDetail(id: "\(nextId)",
                                 name: request.name,
                                 theme: request.theme,
                                 year: request.year,
                                 description: request.description,
                                 visibility: request.visibility,
                                 status: .active,
                                 recipient: ListPerson(id: request.recipientId, displayName: "New Recipient"),
                                 owner: ListPerson(id: "current-user",
                                                   displayName: "Current User"),
                                 coOwner: request.coOwnerId != nil ? ListPerson(id: request.coOwnerId!, displayName: "Co-Owner") : nil,
                                 myRole: .owner,
                                 itemCount: 0,
                                 purchasedCount: 0,
                                 totalBudget: nil,
                                 totalSpent: 0,
                                 members: [],
                                 createdAt: Date(),
                                 updatedAt: Date())
        
        nextId += 1
        lists.append(newList)
        
        LogInfo("Mock: Create list '\(newList.name)'", category: .business)
        
        return newList
        
    }
    
    func updateList(id: String, _ request: UpdateListRequest) async throws -> ListDetail {
        LogDebug("Mock updateList", category: .business)
        
        try await Task.sleep(for: .seconds(delay))
        
        if shouldFail {
            throw ListError.updateFailed
        }
        
        guard let index = lists.firstIndex(where: { $0.id == id }) else {
            throw ListError.notFound
        }
        
        let existing = lists[index]
        
        let updated = ListDetail(id: existing.id,
                                 name: request.name ?? existing.name,
                                 theme: request.theme ?? existing.theme,
                                 year: existing.year,
                                 description: request.description ?? existing.description,
                                 visibility: request.visibility ?? existing.visibility,
                                 status: existing.status,
                                 recipient: existing.recipient,
                                 owner: existing.owner,
                                 coOwner: existing.coOwner,
                                 myRole: existing.myRole,
                                 itemCount: existing.itemCount,
                                 purchasedCount: existing.purchasedCount,
                                 totalBudget: existing.totalBudget,
                                 totalSpent: existing.totalSpent,
                                 members: existing.members,
                                 createdAt: existing.createdAt,
                                 updatedAt: Date())
        lists[index] = updated
        
        LogInfo("Mock: Updated list '\(updated.name)'", category: .business)
        
        return updated
    }
    
    func deleteList(id: String) async throws {
        LogDebug("Mock deleteList", category: .business)
        
        try await Task.sleep(for: .seconds(delay))
        
        if shouldFail {
            throw ListError.deleteFailed
        }
        
        guard let index = lists.firstIndex(where: { $0.id == id }) else {
            throw ListError.notFound
        }
        
        let deleted = lists.remove(at: index)
        
        LogInfo("Mock: Deleted list '\(deleted.name)'")
    }
    
    
    
}
// MARK: - Mock Data

enum MockListData {
    static let allLists: [ListDetail] = [
        ListDetail(
            id: "1",
            name: "Christmas 2024",
            theme: "Winter Wonderland",
            year: 2024,
            description: "Holiday gifts for Tommy",
            visibility: .private,
            status: .active,
            recipient: ListPerson(id: "r1", displayName: "Tommy"),
            owner: ListPerson(id: "o1", displayName: "Jane Doe"),
            coOwner: nil,
            myRole: .member,
            itemCount: 12,
            purchasedCount: 8,
            totalBudget: 300.0,
            totalSpent: 245.50,
            members: [
                ListMember(
                    id: "m1",
                    userId: "u1",
                    userName: "Jane Doe",
                    userEmail: "jane@example.com",
                    role: .owner,
                    joinedAt: Date().addingTimeInterval(-30 * 24 * 60 * 60),
                    invitationStatus: .accepted
                ),
                ListMember(
                    id: "m2",
                    userId: "current-user",
                    userName: "Current User",
                    userEmail: "current@example.com",
                    role: .member,
                    joinedAt: Date().addingTimeInterval(-14 * 24 * 60 * 60),
                    invitationStatus: .accepted
                )
            ],
            createdAt: Date().addingTimeInterval(-30 * 24 * 60 * 60),
            updatedAt: Date().addingTimeInterval(-2 * 24 * 60 * 60)
        ),
        ListDetail(
            id: "2",
            name: "My Birthday List",
            theme: nil,
            year: 2024,
            description: nil,
            visibility: .inviteOnly,
            status: .active,
            recipient: ListPerson(id: "current-user", displayName: "Me"),
            owner: ListPerson(id: "current-user", displayName: "Current User"),
            coOwner: nil,
            myRole: .owner,
            itemCount: nil, // Hidden from owner
            purchasedCount: nil,
            totalBudget: nil,
            totalSpent: 0,
            members: [
                ListMember(
                    id: "m3",
                    userId: "current-user",
                    userName: "Current User",
                    userEmail: "current@example.com",
                    role: .owner,
                    joinedAt: Date().addingTimeInterval(-15 * 24 * 60 * 60),
                    invitationStatus: .accepted
                )
            ],
            createdAt: Date().addingTimeInterval(-15 * 24 * 60 * 60),
            updatedAt: Date().addingTimeInterval(-1 * 24 * 60 * 60)
        ),
        ListDetail(
            id: "3",
            name: "Holiday Shopping",
            theme: "Festive Fun",
            year: 2024,
            description: "Family gift exchange",
            visibility: .inviteOnly,
            status: .active,
            recipient: ListPerson(id: "r3", displayName: "Mom"),
            owner: ListPerson(id: "o2", displayName: "Dad"),
            coOwner: ListPerson(id: "current-user", displayName: "Current User"),
            myRole: .coOwner,
            itemCount: 8,
            purchasedCount: 8,
            totalBudget: 500.0,
            totalSpent: 432.75,
            members: [
                ListMember(
                    id: "m4",
                    userId: "o2",
                    userName: "Dad",
                    userEmail: "dad@example.com",
                    role: .owner,
                    joinedAt: Date().addingTimeInterval(-60 * 24 * 60 * 60),
                    invitationStatus: .accepted
                ),
                ListMember(
                    id: "m5",
                    userId: "current-user",
                    userName: "Current User",
                    userEmail: "current@example.com",
                    role: .coOwner,
                    joinedAt: Date().addingTimeInterval(-45 * 24 * 60 * 60),
                    invitationStatus: .accepted
                )
            ],
            createdAt: Date().addingTimeInterval(-60 * 24 * 60 * 60),
            updatedAt: Date()
        )
    ]
}
