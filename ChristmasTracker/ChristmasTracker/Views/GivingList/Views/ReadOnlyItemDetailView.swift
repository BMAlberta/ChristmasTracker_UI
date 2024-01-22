//
//  ReadOnlyItemDetailView.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 12/28/23.
//

import SwiftUI
import Combine

struct ReadOnlyItemDetailView: View {
    @EnvironmentObject var _session: UserSession
    @StateObject var viewModel: ItemDetailViewModel
    @Environment(\.presentationMode) var presentationMode
    
    
    
    var body: some View {
        Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)
    }
}


#Preview {
    ReadOnlyItemDetailView(viewModel: ItemDetailViewModel(UserSession(), 
                                                          listInfo: ListInfo(listId: "abc",listStatus: .active), itemModel: Item(id: "1234", createdBy: "Brian", creationDate: "2023-12-28", description: "This is an item that has a really long description", lastEditDate: "2023-12-28", link: "www.lowes.com", name: "Drill", price: 230.00, purchased: false, purchaseDate: nil, quantity: 1)))

}
