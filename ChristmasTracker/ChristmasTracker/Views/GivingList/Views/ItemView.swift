//
//  ItemView.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 11/4/24.
//


import SwiftUI
import Combine
import UIKit

struct ItemView: View {
    @EnvironmentObject var _session: UserSession
    @Environment(\.dismiss) private var dismiss
    @StateObject var viewModel: ItemDetailViewModel
    @State var showingEditFlow = false
    @State private var showEditPopover = false
    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack {
                if (viewModel.itemModel.createdBy != _session.loggedInUser?._id) {
                    TagsView(purchaseState: viewModel.itemModel.purchaseState, offListItem: viewModel.itemModel.offListItem)
                }
                StaticElementView(title: "Name", data: viewModel.itemModel.name)
                StaticElementView(title: "Description", data: viewModel.itemModel.description)
                
                StaticLinkView(title: "Link", data: viewModel.itemModel.link)
                HStack {
                    StaticElementView(title: "Price", data: String(format: "$%.2f", viewModel.itemModel.price))
                    StaticElementView(title: "Quantity Requested", data: String(viewModel.itemModel.quantity))
                }
                if (viewModel.itemModel.createdBy == _session.loggedInUser?._id) {
                    StaticElementView(title: "Last Edit Date", data: FormatUtility.convertDateStringToHumanReadable(rawDate: viewModel.itemModel.lastEditDate))
                }
                
                if (viewModel.itemModel.deleteAllowed) {
                    DeleteButton(viewModel: viewModel, dismiss: dismiss)
                        .padding()
                } else if (viewModel.itemModel.purchasesAllowed) {
                    HStack {
                        StaticElementView(title: "Purchase Date", data: FormatUtility.convertDateOnlyStringToHumanReadable(rawDate: viewModel.itemModel.purchaseDate))
                        StaticElementView(title: "Quantity Purchased", data: String(viewModel.itemModel.quantityPurchased))
                    }
                    HStack {
                        PurchaseButton(viewModel: viewModel)
                        if (viewModel.itemModel.retractablePurchase) {
                            RetractButton(viewModel: viewModel)
                        }
                    }
                    .padding(EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8))
                }
            }
        }
        .sheet(isPresented: $showingEditFlow, onDismiss: nil, content: {
            let viewModel = NewItemViewModel(_session, listInContext: viewModel.listInfo.listId, baseModel: viewModel.itemModel)
            NewItemView(viewModel: viewModel, showingModal: $showingEditFlow, editModeActive: true)
        })
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if (viewModel.itemModel.editAllowed) {
                    EditItemButton(showingEditFlow: $showingEditFlow)
                        .popover(isPresented: $showEditPopover) {
                            EducationView(model: self.viewModel.educationModel)
                                .frame(width: 275, height:250)
                                .presentationBackground(Color.green.opacity(0.1))
                                .presentationCompactAdaptation(.none)
                                
                        }
                }
            }
        }
        .padding()
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.showEditPopover = self.viewModel.shouldShowEducationPopover
            }
        }
    }
    
    

//.presentationCompactAdaptation(.none)
    }

struct EditItemButton: View {
    @Binding var showingEditFlow: Bool
    var body: some View {
        Button(action: {
            self.showingEditFlow.toggle()
        }) {
            Image(systemName: "square.and.pencil")
        }
    }
}

    struct TagsView: View {
        var purchaseState: PurchaseState
        var offListItem: Bool
        var body: some View {
            HStack {
                Spacer()
                VStack {
                    Text("Purchase State")
                        .font(.caption2)
                    PurchaseCapsuleView(state: purchaseState)
                }
                Spacer()
                VStack {
                    Text("Item Type")
                        .font(.caption2)
                    ItemStateCapsuleView(offlistItem: offListItem)
                }
                Spacer()
            }
        }
    }
    
    struct StaticElementView: View {
        var title: String?
        var data: String
        var body: some View {
            VStack {
                if let titleString = title {
                    Text(titleString)
                }
                Text(data)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .font(.body)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(3)
                    .overlay(RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.green, lineWidth: 1))
                    .background(Color(UIColor.systemBackground))
                    .cornerRadius(10)
                    .padding(EdgeInsets(top: 0, leading: 10, bottom: 10, trailing: 10))
            }
        }
    }
    
    struct StaticLinkView: View {
        var title: String
        var data: String
        var body: some View {
            VStack {
                Text(title)
                if let url = (Self.prepareLink(input: data)) {
                    Link(data, destination: url)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .font(.body)
                        .lineLimit(1)
                        .textSelection(.enabled)
                        .multilineTextAlignment(.leading)
                        .overlay(RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.green, lineWidth: 1))
                        .background(Color(UIColor.systemBackground))
                        .cornerRadius(10)
                        .padding(EdgeInsets(top: 0, leading: 10, bottom: 10, trailing: 10))
                } else {
                    Text(data)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .font(.body)
                        .textSelection(.enabled)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(1)
                        .overlay(RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.green, lineWidth: 1))
                        .background(Color(UIColor.systemBackground))
                        .cornerRadius(10)
                        .padding(EdgeInsets(top: 0, leading: 10, bottom: 10, trailing: 10))
                }
            }
        }
        
        static func prepareLink(input: String) -> URL? {
            if input.contains("http://") || input.contains("https://") {
                return URL(string: input)
            }
            
            if input.contains("www") || input.contains(".com") {
                return URL(string: "https://"+input)
            }
            return nil
        }
    }
    
    struct PurchaseButton: View {
        @StateObject var viewModel: ItemDetailViewModel
        @State private var isPurchaseAlertDisplayed = false
        @State private var inputText = ""
        var buttonColor: Color {
            return Color("brandBackgroundPrimary")
        }
        var body: some View {
            Button(action: {
                if viewModel.itemModel.quantity == 1 {
                    Task {
                        await updatePurchase()
                    }
                } else {
                    isPurchaseAlertDisplayed = true
                }
            }) {
                Text("Purchase")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: 50)
                    .background(buttonColor)
                    .cornerRadius(15.0)
            }
            .alert(
                Text("Confirm Purchase"),
                isPresented: $isPurchaseAlertDisplayed
            ) {
                Button("Cancel", role: .cancel) {
                    // Handle the acknowledgement.
                }
                Button("OK") {
                    // Handle the acknowledgement.
                    Task {
                        await updatePurchase(quantity: inputText)
                    }
                }
                
                TextField("Quantity Purchased", text: $inputText)
                    .keyboardType(.numberPad)
            } message: {
                Text("Please enter the quantity you purchased.")
            }
        }
        
        
        private func updatePurchase(quantity: String? = nil) async {
            await viewModel.performAction(.purchase, quantity: quantity)
        }
    }
    
    struct RetractButton: View {
        @StateObject var viewModel: ItemDetailViewModel
        var buttonColor: Color {
            return Color("brandBackgroundSecondary")
        }
        var body: some View {
            Button(action: {
                Task {
                    await viewModel.performAction(.retract)
                }
            }) {
                Text("Retract")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: 50)
                    .background(buttonColor)
                    .cornerRadius(15.0)
            }
        }
    }
    
    struct DeleteButton: View {
        @StateObject var viewModel: ItemDetailViewModel
        var dismiss: DismissAction
        var body: some View {
            Button(action: {
                Task {
                    await viewModel.performAction(.delete)
                    dismiss()
                }
            }) {
                Text("Delete Item")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                //                    .frame(width: 300, height: 50)
                    .frame(maxWidth: .infinity, maxHeight: 50)
                    .background(Color("brandBackgroundSecondary"))
                    .cornerRadius(15.0)
            }
        }
    }


struct ItemView_Previews: PreviewProvider {
    static var previews: some View {
        BindItemViewPreview()
            .preferredColorScheme(.dark)
    }
}

struct BindItemViewPreview : View {
    @State
    private var value = false
    let session = UserSession()
    var body: some View {
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
                        retractablePurchase: true,
                        offListItem: false,
                        purchaseState: .available,
                        purchasesAllowed: true,
                        quantityPurchased: 0,
                        deleteAllowed:false,
                        editAllowed: false)
        let viewModel = ItemDetailViewModel(session, listInfo: ListInfo(listId: "abc", listStatus: .active), itemModel: item)
        ItemView(viewModel: viewModel)
            .environmentObject(session)
    }
}
