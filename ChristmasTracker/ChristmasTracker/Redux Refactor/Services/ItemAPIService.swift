//
//  ItemAPIService.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 10/1/25.
//

import Foundation

protocol ItemDataProviding {

    func addNewItem(toList listInContext: String, newItem: NewItemModel) async throws -> ListDetailResponse
    func markItemPurchased(listId: String, itemInContext: Item, quantity: Int) async throws -> ListDetailResponse
    func markItemRetracted(listId: String, itemInContext: Item) async throws -> ListDetailResponse
    func updateItem(listInContext: String, updatedItem: NewItemModel) async throws -> ListDetailResponse
    func deleteItem(fromList listId: String, item: Item) async throws
    
}

actor ItemAPIService: ItemDataProviding {
    func addNewItem(toList listInContext: String, newItem: NewItemModel) async throws -> ListDetailResponse {
        return ListDetailResponse(detail: ListDetailModel(name: "Foo",
                                                          owner: "Foo",
                                                          members: ["Foo"],
                                                          id: "Foo",
                                                          creationDate: "123",
                                                          lastUpdateDate: "123",
                                                          status: .active,
                                                          items: [], __v: 1))
    }
    
    func markItemPurchased(listId: String, itemInContext: Item, quantity: Int) async throws -> ListDetailResponse {
        return ListDetailResponse(detail: ListDetailModel(name: "Foo",
                                                          owner: "Foo",
                                                          members: ["Foo"],
                                                          id: "Foo",
                                                          creationDate: "123",
                                                          lastUpdateDate: "123",
                                                          status: .active,
                                                          items: [], __v: 1))
    }
    
    func markItemRetracted(listId: String, itemInContext: Item) async throws -> ListDetailResponse {
        return ListDetailResponse(detail: ListDetailModel(name: "Foo",
                                                          owner: "Foo",
                                                          members: ["Foo"],
                                                          id: "Foo",
                                                          creationDate: "123",
                                                          lastUpdateDate: "123",
                                                          status: .active,
                                                          items: [], __v: 1))
    }
    
    func updateItem(listInContext: String, updatedItem: NewItemModel) async throws -> ListDetailResponse {
        return ListDetailResponse(detail: ListDetailModel(name: "Foo",
                                                          owner: "Foo",
                                                          members: ["Foo"],
                                                          id: "Foo",
                                                          creationDate: "123",
                                                          lastUpdateDate: "123",
                                                          status: .active,
                                                          items: [], __v: 1))
    }
    
    func deleteItem(fromList listId: String, item: Item) async throws {
    
    }
    
    
}
