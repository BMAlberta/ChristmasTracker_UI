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
    @EnvironmentObject var _store: AppStore
    @State var model: Item
    @Environment(\.presentationMode) var presentationMode
    
    private var purchaseActionSuccess: Bool {
        return _store.state.ownedList.isFetchError == false && _store.state.ownedList.purchaseComplete == true
    }
    
    var body: some View {
        let shouldDisplayError =  Binding<Bool>(
            get: { _store.state.ownedList.isFetchError == true},
            set: { _ in _store.dispatch(.list(action: .fetchError(error: nil))) }
        )
        ZStack {
            Form {
                Section("Item Details") {
                    StaticElementView(title: "Name", data: model.name)
                    StaticElementView(title: "Description", data: model.description)
                    
                    StaticLinkView(title: "Link", data: model.link)
                    HStack {
                        StaticElementView(title: "Price", data: String(format: "$%.2f", model.price))
                        StaticElementView(title: "Quantity", data: String(model.quantity))
                    }
                }
                Section("Item History") {
                    
                    StaticElementView(title: "Last Edit Date", data: FormatUtility.convertDateStringToHumanReadable(rawDate: model.lastEditDate))
                    if (model.retractablePurchase) {
                        StaticElementView(title: "Purchase Date", data: FormatUtility.convertDateStringToHumanReadable(rawDate: model.purchaseDate))
                        
                        PurchaseButton(model: model)
                            .disabled(purchaseActionSuccess)
                    } else {
                        DeleteButton(model: model)
                    }
                }
            }
            .padding()
            .background(Color(UIColor.systemBackground))
            .navigationBarTitle("Item Detail", displayMode: .inline)
            .onChange(of: _store.state.ownedList.purchaseComplete, perform: { _ in
                print("On Change!")
                if purchaseActionSuccess && !model.retractablePurchase {
                    _store.dispatch(.list(action: .fetchListOverview(token: _store.state.auth.token)))
                    self.presentationMode.wrappedValue.dismiss()
                }
            })
            .alert(isPresented: shouldDisplayError) {
                Alert(title: Text("Error"), message: Text("We're temporarily unable to complete this action. Please try again later."), dismissButton: .default(Text("Ok")))
            }
            if (_store.state.ownedList.fetchInProgess) {
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
                    .overlay(RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.green, lineWidth: 1))
                    .background(Color(UIColor.systemBackground))
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
                Link(data, destination: Self.prepareLink(input: data))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .font(.body)
                    .multilineTextAlignment(.leading)
                    .overlay(RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.green, lineWidth: 1))
                    .background(Color(UIColor.systemBackground))
                    .padding(EdgeInsets(top: 0, leading: 10, bottom: 10, trailing: 10))
            }
        }
        
        static func prepareLink(input: String) -> URL {
            if input.contains("http://") || input.contains("https://") {
                return URL(string: input)!
            } else {
                return URL(string: "https://"+input)!
            }
        }
    }
    
    struct PurchaseButton: View {
        @EnvironmentObject var _store: AppStore
        @ObservedObject var model: Item
        
        var buttonColor: Color {
            if (_store.state.ownedList.isFetchError == false && _store.state.ownedList.purchaseComplete == true) {
                return Color.gray
            }
            else {
                return model.purchased ? Color("brandBackgroundSecondary") : Color("brandBackgroundPrimary")
            }
        }
        var body: some View {
            Button(action: {
                print("Save tapped")
                updatePurchase(item: model)
                
            }) {
                Text(model.purchased ? "Retract Purchase" : "Purchase")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(width: 300, height: 50)
                    .background(buttonColor)
                    .cornerRadius(15.0)
            }/**.padding(.top, 50)*/
        }
        
        private func updatePurchase(item: Item) {
            if item.purchased {
                _store.dispatch(.list(action: .retractPurchase(item: item)))
            } else {
                _store.dispatch(.list(action: .purchaseItem(item: item)))
            }
        }
    }
    
    struct DeleteButton: View {
        @EnvironmentObject var _store: AppStore
        @ObservedObject var model: Item

        var body: some View {
            Button(action: {
                print("Delete tapped")
                _store.dispatch(.list(action: .deleteItem(token: _store.state.auth.token, item: model)))
            }) {
                Text("Delete Item")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(width: 300, height: 50)
                    .background(Color("brandBackgroundSecondary"))
                    .cornerRadius(15.0)
            }/**.padding(.top, 50)*/
        }
    }
}

struct ItemDetailView_Previews: PreviewProvider {
    static var previews: some View {
        BindingItemViewPreview()
    }
}

struct BindingItemViewPreview : View {
    @State
    private var value = false
    
    var body: some View {
        
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
        let item = Item(id: "1234",
                        createdBy: "Brian",
                        creationDate: "2021-10-04",
                        description: "Cordless drill",
                        lastEditDate: "2021-10-04",
                        link: "www.lowes.com",
                        name: "Drill",
                        price: 230.00,
                        purchased: false,
                        purchaseDate: nil,
                        quantity: 1,
                        v: 1)
        ItemDetailView(model: item).environmentObject(store)
    }
}
