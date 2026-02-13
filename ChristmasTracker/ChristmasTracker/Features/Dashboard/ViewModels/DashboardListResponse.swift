import Foundation

nonisolated struct DashboardListsResponse: Codable, Sendable {
    let success: Bool
    let data: ListsData

    var lists: [GiftList] {
        data.lists
    }
}

nonisolated struct ListsData: Codable, Sendable {
    let lists: [GiftList]
}
