//
//  ItemDetailView.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 10/6/21.
//

import SwiftUI
import Combine
import UIKit

struct ItemDetailView: View {
    @EnvironmentObject var _session: UserSession
    @StateObject var viewModel: ItemDetailViewModel
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ZStack {
            
            VStack {
                HStack{
                    Spacer()
                    Spacer()
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .padding(EdgeInsets(top: 16, leading: 8, bottom: 0, trailing: 16))
                    }
                }
                
                Form {
                    Section("Item Details") {
                        StaticElementView(title: "Name", data: viewModel.itemModel.name)
                        StaticElementView(title: "Description", data: viewModel.itemModel.description)
                        
                        StaticLinkView(title: "Link", data: viewModel.itemModel.link)
                        HStack {
                            StaticElementView(title: "Price", data: String(format: "$%.2f", viewModel.itemModel.price))
                            StaticElementView(title: "Quantity", data: String(viewModel.itemModel.quantity))
                        }
                    }
                    Section("Item History") {
                        
                        StaticElementView(title: "Last Edit Date", data: FormatUtility.convertDateStringToHumanReadable(rawDate: viewModel.itemModel.lastEditDate))
                        if (viewModel.itemModel.createdBy == _session.loggedInUser?._id) {
                            DeleteButton(viewModel: viewModel)
                                
                        } else {
                            StaticElementView(title: "Purchase Date", data: FormatUtility.convertDateStringToHumanReadable(rawDate: viewModel.itemModel.purchaseDate))
                            if (viewModel.itemModel.retractablePurchase || !viewModel.itemModel.purchased) {
                                PurchaseButton(viewModel: viewModel)
                                    .disabled(viewModel.isPurchaseSuccessful)
                                    
                            }
                        }
                    }
                }
                .padding()
                .background(Color(UIColor.systemBackground))
                .navigationBarTitle("Item Detail", displayMode: .inline)
                .onChange(of: viewModel.isPurchaseSuccessful, perform: { _ in
                    if viewModel.isPurchaseSuccessful /*&& viewModel.itemModel.retractablePurchase*/ {
                        NotificationCenter.default.post(name: Notification.Name("purchaseStatusChanged"), object: nil)
                        self.presentationMode.wrappedValue.dismiss()
                    } else if !viewModel.isPurchaseSuccessful && viewModel.itemModel.retractablePurchase {
                        viewModel.isErrorState = true
                    }
                })
                .alert(isPresented: $viewModel.isErrorState) {
                    Alert(title: Text("Error"), message: Text("We're temporarily unable to complete this action. Please try again later."), dismissButton: .default(Text("Ok")))
            }
            }
            if (viewModel.isLoading) {
                ProgressView()
            }
        }

    }
    
    struct StaticElementView: View {
        var title: String
        var data: String
        var body: some View {
            VStack {
                Text(title)
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
        
        var buttonColor: Color {
            if (!viewModel.isErrorState && viewModel.isPurchaseSuccessful) {
                return Color.gray
            }
            else {
                return viewModel.itemModel.purchased ? Color("brandBackgroundSecondary") : Color("brandBackgroundPrimary")
            }
        }
        var body: some View {
            Button(action: {
                Task {
                    await updatePurchase()
                }
            }) {
                Text(viewModel.itemModel.purchased ? "Retract Purchase" : "Purchase")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
//                    .frame(width: 300, height: 50)
                    .frame(maxWidth: .infinity, maxHeight: 50)
                    .background(buttonColor)
                    .cornerRadius(15.0)
            }/**.padding(.top, 50)*/
        }
        
        private func updatePurchase() async {
            if viewModel.itemModel.purchased {
                await viewModel.performAction(.retract)
            } else {
                await  viewModel.performAction(.purchase)
            }
        }
    }
    
    struct DeleteButton: View {
        @StateObject var viewModel: ItemDetailViewModel
        
        var body: some View {
            Button(action: {
                Task {
                    await viewModel.performAction(.delete)
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
            }/**.padding(.top, 50)*/
        }
    }
}

struct ItemDetailView_Previews: PreviewProvider {
    static var previews: some View {
        BindingItemViewPreview()
            .preferredColorScheme(.dark)
    }
}

struct BindingItemViewPreview : View {
    @State
    private var value = false
    
    var body: some View {
        let item = Item(id: "1234",
                        createdBy: "Brian",
                        creationDate: "2021-10-04",
                        description: "This an item that has a really long description that hopefully will be truncated properly.",
                        lastEditDate: "2021-10-04",
                        link: "www.lowes.com",
                        name: "Drill",
                        price: 230.00,
                        purchased: false,
                        purchaseDate: nil,
                        quantity: 1)
        let viewModel = ItemDetailViewModel(UserSession(), listInContext: "abc", itemModel: item)
        ItemDetailView(viewModel: viewModel)
    }
}
