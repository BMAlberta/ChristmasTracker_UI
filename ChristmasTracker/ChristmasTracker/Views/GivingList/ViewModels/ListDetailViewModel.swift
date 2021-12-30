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
    
    private var _session: UserSession
    private var _user: SlimUser
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
    
    
    init(_ session: UserSession, userInContext: SlimUser) {
        _session = session
        _user = userInContext
        self.userDisplayName = _user.firstName
        NotificationCenter.default.addObserver(self, selector: #selector(refreshList), name: Notification.Name("purchaseStatusChanged"), object: nil)
    }
    
    @objc private func refreshList() {
        Task {
            await getDetails()
        }
    }
    
    @MainActor
    func getDetails() async {
        self.isLoading = true
        do {
            let userListResponse: AllItemsResponse = try await ListServiceStore.getListForUser(_session.token, userId: _user.rawId)
            let sortedItems = userListResponse.items.sorted { !$0.purchased && $1.purchased }
            self.items = sortedItems
            self.userDisplayName = _user.firstName
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
