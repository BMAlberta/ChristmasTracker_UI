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
    @State private var isNewItemFlowPresented = false
    @State private var isActionSheetPresented = false
    @State var selectedItem: Item?
    @State private var selectedFilterAmount: ListDetailViewModel.FilterValue = .all
    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()
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
                        Section {
                            let newViewModel = ItemDetailViewModel(_session, listInfo: ListInfo(listId:viewModel.activeListId, listStatus: viewModel.listStatus), itemModel: i)
                            NavigationLink(destination: LazyView(ItemView(viewModel: newViewModel))) {
                                ItemCardView(viewModel: ItemCardViewModel(_session, listContext: viewModel.activeListId, itemInContext: i), isActionSheetPresented: isActionSheetPresented)
                            }
                        }
                    }
                    .onDelete(perform: delete)
                    .deleteDisabled(!self.viewModel.hidePurchases || self.viewModel.listStatus != .active)
                }
                .listStyle(.insetGrouped)
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
            .navigationBarItems(trailing: (viewModel.listStatus == .active) ? addItemButton : nil)
        }
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
    
    private func delete(at offsets: IndexSet) {
        Task() {
            await self.viewModel.deleteItem(at: offsets)
        }
    }
    
    private var addItemButton: some View {
        Button(action: {
            self.isNewItemFlowPresented.toggle()
        }) {
            Image(systemName: "plus")
        }.sheet(isPresented: $isNewItemFlowPresented) {
            let newItemViewModel = NewItemViewModel(_session, listInContext: viewModel.activeListId)
            NewItemView(viewModel: newItemViewModel, showingModal: $isNewItemFlowPresented)
            EmptyView()
        }
    }
}

struct ListDetailView_Previews: PreviewProvider {
    
    static let user = SlimUserModel(firstName: "Brian", lastName: "Alberta", rawId: "615d0aca9dce0250b0eac9c2")
    
    static let list = ListOverviewDetails(listName: "Fake Name", totalItems: 10, purchasedItems: 8, id: "615d0aca9dce0250b0eac9c2", lastUpdateDate: "2022-12-12 12:12:12", listStatus: .active, ownerInfo: user, memberDetails: [MemberDetail(firstName: "Brian", lastName: "Alberta", id: "1234")])
    
    
    
        
      static let userItems = [Item(id: "1234",
                                                createdBy: "Brian",
                                                creationDate: "2021-10-04",
                                                description: "This an item that has a really long description that hopefully will be truncated properly.",
                                                lastEditDate: "2021-10-04",
                                                link: "www.lowes.com",
                                                name: "Drill",
                                                price: 230.00,
                                                purchaseDate: nil,
                                                quantity: 1,
                                   retractablePurchase: false,
                                   offListItem: false,
                                   purchaseState: .available,
                                   purchasesAllowed: true,
                                   quantityPurchased: 0,
                                   deleteAllowed:true,
                                   editAllowed: false,
                                   canViewMedata: false),
                                           Item(id: "1234",
                                                createdBy: "Brian",
                                                creationDate: "2021-10-04",
                                                description: "This an item that has a really long description that hopefully will be truncated properly.",
                                                lastEditDate: "2021-10-04",
                                                link: "www.lowes.com",
                                                name: "Drill",
                                                price: 230.00,
                                                purchaseDate: nil,
                                                quantity: 1,
                                                retractablePurchase: false,
                                                offListItem: false,
                                                purchaseState: .available,
                                                purchasesAllowed: true,
                                                quantityPurchased: 0,
                                                deleteAllowed:true,
                                                editAllowed: false,
                                                canViewMedata: false)]
    
    
    static var previews: some View {
        let session = UserSession()
        let viewModel = ListDetailViewModel(session, listInContext: Self.list, items: userItems)
        ListDetailView(viewModel: viewModel)
            .environmentObject(session)
    }
}


