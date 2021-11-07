//
//  ListDetailView.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 10/5/21.
//

import SwiftUI

struct ListDetailView: View {
    
    
    private enum FilterValue: String, CaseIterable, Identifiable {
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
    
    
    @EnvironmentObject var _store: AppStore
    var user: SlimUser
    @State private var isDetailPresented = false
    @State var selectedItem: Item?
    @State private var selectedFilterAmoount: FilterValue = .all
    var body: some View {
        VStack(alignment: .leading, spacing: 0, content: {
            Text("Filter By Price")
                .font(.caption)
                .foregroundColor(Color(uiColor: .systemGray))
                .padding(EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16))
        
            Picker("", selection: $selectedFilterAmoount, content: {
                ForEach(FilterValue.allCases) { filterValue in
                    Text(filterValue.displayText).tag(filterValue)
                }
            })
                .pickerStyle(.segmented)
                .padding(EdgeInsets(top: 0, leading: 16, bottom: 4, trailing: 16))
            List {
                    ForEach(filterItems(), id: \.id) { i in
                        ListItemView(data: i, hidePurchase: false)
                            .onTapGesture {
                                selectedItem = i
                                isDetailPresented = true
                            }
                    }
            }
            .listStyle(.plain)
            .padding()
            .sheet(item: $selectedItem, onDismiss: {
                _store.state.ownedList.purchaseComplete = false
                isDetailPresented = false
            }, content: { item in
                LazyView(ItemDetailView(model: item))
            })
            .onAppear {
                let token = _store.state.auth.token
                _store.dispatch(.list(action: .fetchUserList(token: token, userId: user.rawId)))
            }
        })
            .navigationViewStyle(.stack)
            .navigationTitle("\(user.firstName)'s List")
    }
    
    
    private func filterItems() -> [Item] {
        switch selectedFilterAmoount {
        case .all:
            return _store.state.ownedList.userItems
        case .underTwentyFive:
            
            let allItems = _store.state.ownedList.userItems
            let filteredItems = allItems.filter { $0.price < 25.00 }
            return filteredItems
            
        case .betweenTwentyFiveAndFifty:
            let allItems = _store.state.ownedList.userItems
            let filteredItems = allItems.filter { (25.00..<50.00).contains($0.price) }
            return filteredItems
    
        case .betweenFiftyAndOneHundred:
            let allItems = _store.state.ownedList.userItems
            let filteredItems = allItems.filter { (50.00...100.00).contains($0.price) }
            return filteredItems
            
        case .overOneHundred:
            let allItems = _store.state.ownedList.userItems
            let filteredItems = allItems.filter { $0.price > 100.00 }
            return filteredItems
        }
    }
    
    private struct ListHeaderView: View {
        var numberOfItems: Int = 0
        
        var body: some View {
            Text("\(numberOfItems) items in this range.")
                .font(.caption)
        }
    }
}

struct ListDetailView_Previews: PreviewProvider {
    
    static let user = SlimUser(firstName: "Brian", lastName: "Alberta", rawId: "615d0aca9dce0250b0eac9c2")
    
    
    static func generateStore() -> AppStore {
        
        let store = AppStore(initialState: .init(
            authState: AuthState(),
            listState: ListState()
        ),
                             reducer: appReducer,
                             middlewares: [
                                authMiddleware(service: AuthService()),
                                logMiddleware(),
                                listMiddleware(service: ListService())
                             ])
        
        store.state.ownedList.userItems = [Item(id: "1234",
                                                createdBy: "Brian",
                                                creationDate: "2021-10-04",
                                                description: "This an item that has a really long description that hopefully will be truncated properly.",
                                                lastEditDate: "2021-10-04",
                                                link: "www.lowes.com",
                                                name: "Drill",
                                                price: 230.00,
                                                purchased: false,
                                                purchaseDate: nil,
                                                quantity: 1,
                                                v: 1),
                                           Item(id: "1234",
                                                createdBy: "Brian",
                                                creationDate: "2021-10-04",
                                                description: "This an item that has a really long description that hopefully will be truncated properly.",
                                                lastEditDate: "2021-10-04",
                                                link: "www.lowes.com",
                                                name: "Drill",
                                                price: 230.00,
                                                purchased: false,
                                                purchaseDate: nil,
                                                quantity: 1,
                                                v: 1)]
        
        return store
    }
    
    
    static var previews: some View {
        ListDetailView(user: Self.user).environmentObject(Self.generateStore())
    }
}


