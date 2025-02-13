//
//  ItemCardView.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 10/27/22.
//

import SwiftUI
import Combine

struct ItemCardView: View {
    @ObservedObject var viewModel: ItemCardViewModel
    @State var isActionSheetPresented = false
    
    var body: some View {
        VStack(alignment: .leading) {
            if viewModel.itemModel.canViewMetadata {
                HStack {
                    PurchaseCapsuleView(state: self.viewModel.itemModel.purchaseState)
//                    Spacer()
//                    takeActionButton
                }
            }
            Text("\(viewModel.itemModel.name)")
                .font(.title2)
                .padding(EdgeInsets(top: viewModel.itemModel.canViewMetadata ? 0 : -8, leading: 0, bottom: 0, trailing: 0))
            Text("Last update: \(FormatUtility.convertDateStringToHumanReadable(rawDate: viewModel.itemModel.lastEditDate))")
                .font(.caption)
                .foregroundColor(Color.gray)
                .padding(EdgeInsets(top: 0, leading: 0, bottom: 8, trailing: 0))
            Text("\(viewModel.itemModel.description)")
                .font(.subheadline)
                .lineLimit(2)
                .truncationMode(.tail)
                .padding(EdgeInsets(top: 0, leading: 0, bottom: 8, trailing: 0))
            Text("Price")
                .foregroundColor(.gray)
            Text("$\(viewModel.itemModel.price, specifier: "%.2f")")
                .font(.title3)
                .fontWeight(.thin)
                .padding(EdgeInsets(top: 0, leading: 0, bottom: 8, trailing: 0))
            Text("Quantity(\(viewModel.itemModel.quantity))")
                .font(.caption2)
        }
    }
    
    private var takeActionButton: some View {
        Button(action: {
            isActionSheetPresented = true
        }) {
            Image(systemName: "ellipsis")
                .padding(EdgeInsets(top: 20, leading: 20, bottom: 20, trailing: 8))
        }.confirmationDialog(
            "Select an action to take.",
            isPresented: $isActionSheetPresented, presenting: "Actions"
        ) { _ in
            Button {
                Task {
                    let action: ItemCardViewModel.ActionButtonType = self.viewModel.itemModel.retractablePurchase ? .retract : .purchase
                    await self.viewModel.performAction(action)
                }
                isActionSheetPresented = false
            } label: {
                let buttonTitle = self.viewModel.itemModel.retractablePurchase ? "Retract Purchase" : "Purchase Item"
                Text(buttonTitle)
            }
            
            if self.viewModel.itemModel.deleteAllowed {
                Button {
                    Task {
                        let action: ItemCardViewModel.ActionButtonType = .delete
                        await self.viewModel.performAction(action)
                    }
                    isActionSheetPresented = false
                } label: {
                    let buttonTitle = "Delete Item"
                    Text(buttonTitle)
                }
            }
            
            Button("Cancel", role: .cancel) {
                isActionSheetPresented = false
            }
        } message: { detail in
            Text(
                """
                Select an action to take.
                """)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

extension PurchaseState {
    var mappedColor: Color {
        switch self {
        case .available:
            return .green
        case .unavailable:
            return .gray
        case .purchased:
            return.red
        case .partial:
            return .yellow
        }
    }
    
    var mappedText: String {
        switch self {
        case .available:
            return "Available"
        case .purchased:
            return "Purchased"
        case .unavailable:
            return "Unavailable"
        case .partial:
            return "Partial"
        }
    }
    
    var mappedTextColor: Color {
        switch self {
        case .available:
            return .white
        case .purchased:
            return .white
        case .unavailable:
            return .white
        case .partial:
            return .white
        }
    }
}

struct PurchaseCapsuleView: View {
    var state: PurchaseState
  
    var body: some View {
        Text(state.mappedText)
            .font(.system(size: 10))
            .fontWeight(.bold)
            .font(.callout)
            .padding(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            .foregroundColor(state.mappedTextColor)
            .background(state.mappedColor)
            .clipShape(Capsule())
    }
}

struct ItemStateCapsuleView: View {
    var offlistItem = false
  
    var body: some View {
        Text(offlistItem ? "Off-List Item" : "List Item")
            .font(.system(size: 10))
            .fontWeight(.bold)
            .font(.callout)
            .padding(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            .foregroundColor(.white)
            .background(offlistItem ? .yellow: .green)
            .clipShape(Capsule())
    }
}

struct ItemCardView_Previews: PreviewProvider {
    static var previews: some View {
        let item = Item(id: "1234",
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
                        purchaseState: .partial,
                        purchasesAllowed: true,
                        quantityPurchased: 0,
                        deleteAllowed:true,
                        editAllowed: false,
                        canViewMedata: true)
        let viewModel = ItemCardViewModel(UserSession(), listContext: "asdasd", itemInContext: item)
        ItemCardView(viewModel: viewModel)
    }
}


