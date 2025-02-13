//
//  ListDetailViewModel.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 12/5/21.
//

import Foundation
import Combine

class ListDetailViewModel: ObservableObject {
    
    @Published var isLoading = false
    @Published var isErrorState = false
    @Published var items: [Item] = []
    @Published var userDisplayName: String = ""
    @Published var hidePurchases = false
    @Published var allowAdHocItems = false
    @Published var listStatus = ListStatus.archive
    
    private var _session: UserSession
    var activeListId: String
    private var allItems: [Item] = []
    
    enum FilterValue: String, CaseIterable, Identifiable {
        var id: Self { self }
        
        case all
        case underTwentyFive
        case betweenTwentyFiveAndFifty
        case betweenFiftyAndOneHundred
        case overOneHundred
        
        var displayText: String {
            switch self {
            case .all:
                return "All"
            case .underTwentyFive:
                return "< $25"
            case .betweenTwentyFiveAndFifty:
                return "$25 - $50"
            case .betweenFiftyAndOneHundred:
                return "$50 - 100"
            case .overOneHundred:
                return "> $100"
            }
        }
    }
    
    
    init(_ session: UserSession, listInContext: ListOverviewDetails) {
        _session = session
        activeListId = listInContext.id
        self.userDisplayName =  listInContext.ownerInfo.firstName
        self.listStatus = listInContext.listStatus
        NotificationCenter.default.addObserver(self, selector: #selector(refreshList), name: Notification.Name("purchaseStatusChanged"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(refreshList), name: Notification.Name("newItemAdded"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(refreshList), name: Notification.Name("itemDeleted"), object: nil)
    }
    
    init(_ session: UserSession, listInContext: ListOverviewDetails, items: [Item]) {
        _session = session
        activeListId = listInContext.id
        self.userDisplayName =  listInContext.ownerInfo.firstName
        self.allItems = items
    }
    
    
    init(_ session: UserSession, listId: String, displayName: String, purchasesAllowed: Bool = false, listStatus: ListStatus = .archive) {
        _session = session
        activeListId = listId
        self.userDisplayName =  displayName
        self.hidePurchases = !purchasesAllowed
        self.allowAdHocItems = purchasesAllowed
        self.listStatus = listStatus
        if purchasesAllowed {
            NotificationCenter.default.addObserver(self, selector: #selector(refreshList), name: Notification.Name("purchaseStatusChanged"), object: nil)
        } else {
            NotificationCenter.default.addObserver(self, selector: #selector(refreshList), name: Notification.Name("newItemAdded"), object: nil)
        }
        NotificationCenter.default.addObserver(self, selector: #selector(refreshList), name: Notification.Name("itemDeleted"), object: nil)
    }
    
    
    @objc private func refreshList() {
        Task {
            await getDetails()
        }
    }
    
    @objc private func updateList(_ notification: NSNotification) {
        guard let updatedListModel = notification.userInfo?["updatedList"] as? ListDetailModel else {
            return
        }
        let sortedItems = updatedListModel.items.sorted { $0.purchaseState < $1.purchaseState }
        self.items = sortedItems
    }
    
    @MainActor
    func getDetails() async {
        self.isLoading = true
        do {
            let userListResponse: ListDetailModel = try await ListServiceStore.getList(listId: activeListId)
            let sortedItems = Self.sortItems(inputItems: userListResponse.items, ownedList: !userListResponse.canViewMetadata)
            self.items = sortedItems
            self.isLoading = false
            self.isErrorState = false
        } catch {
            self.isLoading = false
            self.isErrorState = true
        }
        
    }
    
    static func sortItems(inputItems: [Item], ownedList: Bool) -> [Item] {
        
        if ownedList {
            return inputItems.sorted { $0.creationDate < $1.creationDate }
        }
        
        return inputItems.sorted { $0.purchaseState < $1.purchaseState }
        
    }
    
    @MainActor
    func deleteItem(at offsets: IndexSet) async {
        let index = offsets[offsets.startIndex]
        let itemInContext = self.items[index]
        
        do {
            self.isLoading = true
            let _ = try await ListServiceStore.deleteItem(fromList: activeListId, item: itemInContext)
            NotificationCenter.default.post(name: Notification.Name("newItemAdded"), object: nil, userInfo: nil)
            let updatedListResponse: ListDetailModel = try await ListServiceStore.getList(listId: activeListId)
            let sortedItems = Self.sortItems(inputItems: updatedListResponse.items, ownedList: !updatedListResponse.canViewMetadata)
            self.items = sortedItems
            self.isLoading = false
            self.isErrorState = false
        } catch {
            self.isLoading = false
            self.isErrorState = true
        }
    }
    func applyFilter(_ selectedFilterAmount: FilterValue) {
        switch selectedFilterAmount {
        case .all:
            items = allItems
        case .underTwentyFive:
            items = allItems.filter { $0.price < 25.00 }
        case .betweenTwentyFiveAndFifty:
            items = allItems.filter { (25.00..<50.00).contains($0.price) }
        case .betweenFiftyAndOneHundred:
            items = allItems.filter { (50.00...100.00).contains($0.price) }
        case .overOneHundred:
            items = allItems.filter { $0.price > 100.00 }
        }
    }
}
