//
//  ListDetailView.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 10/5/21.
//

import SwiftUI

struct ListDetailView: View {
     @EnvironmentObject var _session: UserSession
    @StateObject var viewModel: ListDetailViewModel
    @State private var isDetailPresented = false
    @State var selectedItem: Item?
    @State private var selectedFilterAmount: ListDetailViewModel.FilterValue = .all
    var body: some View {
        VStack(alignment: .leading, spacing: 0, content: {
            Text("Filter By Price")
                .font(.caption)
                .foregroundColor(Color(uiColor: .systemGray))
                .padding(EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16))
        
            Picker("", selection: $selectedFilterAmount, content: {
                ForEach(ListDetailViewModel.FilterValue.allCases) { filterValue in
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
                isDetailPresented = false
            }, content: { item in
                let viewModel = ItemDetailViewModel(_session, itemModel: item)
                LazyView(ItemDetailView(viewModel: viewModel))
            })
            .onAppear {
                Task {
                    await self.viewModel.getDetails()
                }
            }
            .refreshable {
                Task {
                    await self.viewModel.getDetails()
                }
            }
        })
            .navigationViewStyle(.stack)
            .navigationTitle("\(self.viewModel.userDisplayName)'s List")
    }
    
    
    private func filterItems() -> [Item] {
        switch selectedFilterAmount {
        case .all:
            return self.viewModel.items
        case .underTwentyFive:
            
            let allItems = self.viewModel.items
            let filteredItems = allItems.filter { $0.price < 25.00 }
            return filteredItems
            
        case .betweenTwentyFiveAndFifty:
            let allItems = self.viewModel.items
            let filteredItems = allItems.filter { (25.00..<50.00).contains($0.price) }
            return filteredItems
    
        case .betweenFiftyAndOneHundred:
            let allItems = self.viewModel.items
            let filteredItems = allItems.filter { (50.00...100.00).contains($0.price) }
            return filteredItems
            
        case .overOneHundred:
            let allItems = self.viewModel.items
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
    
    
    
        
      static let userItems = [Item(id: "1234",
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
    
    
    static var previews: some View {
        let session = UserSession()
        let viewModel = ListDetailViewModel(session, userInContext: Self.user)
        ListDetailView(viewModel: viewModel)
            .environmentObject(session)
    }
}


