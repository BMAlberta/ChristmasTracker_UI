//
//  ListAPIService.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 10/1/25.
//

import Foundation

protocol ListataProviding {
    func getOwnedItems() async throws -> OwnedListResponse
    func getListOverviewByUser() async throws -> ListOverviewResponse
    func getList(listId: String) async throws -> ListDetailResponse
    func createList(newList: String) async throws -> ListDetailResponse
    func deleteList(listId: String) async throws
}
