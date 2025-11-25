//
//  EditItemView.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 11/3/25.
//

import SwiftUI


import SwiftUI

struct EditItemView: View {
    @Environment(\.dismiss) var dismiss
    var store: Store<AppState>
    @StateObject private var viewStore: ViewStore<EditItemViewState>
    @State private var showingErrorDialog: Bool = false
    @State private var productURL: String = ""
    @State private var price: String = ""
    @State private var quantity: Int = 1
    @State private var priorityLevel: PriorityLevel = .medium
    @State private var itemURLFieldContainsError = false
    @State private var itemPriceFieldContainsError = false
    private var itemInContext: ItemDetails
    private var listInContext: String
    
    var errorsOnForm: Bool {
        return itemURLFieldContainsError || itemPriceFieldContainsError
    }
    
    init(store: Store<AppState>, item: ItemDetails, listInContext: String) {
        self.store = store
        self.itemInContext = item
        self.listInContext = listInContext
        self.productURL = item.link
        self.price = String(format: "%.2f", item.price)
        self.quantity = item.quantity
        self.priorityLevel = item.priority ?? .medium
        self._viewStore = StateObject(wrappedValue: ViewStore(
            store: store,
            observe: { appState in
                return EditItemViewState(
                    isLoading: appState.list.isLoading,
                    error: appState.list.error,
                    updateItemSuccess: appState.list.updateItemSuccess
                )
            }
        ))
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Item Name
                    ItemNameView(itemName: itemInContext.name)
                    
                    // Description
                    DescriptionView(itemDescription: itemInContext.description)
                    
                    // Product URL
                    ItemURLEntryView(productURL: $productURL, fieldInErrorState: $itemURLFieldContainsError)
                    
                    // Price and Quantity
                    HStack(spacing: 16) {
                        ItemPriceEntryView(price: $price, fieldInErrorState: $itemPriceFieldContainsError)
                        
                        ItemQuantityEntryView(quantity: $quantity)
                    }
                    
                    // Priority Level
                    ItemPriorityEntryView(priorityLevel: $priorityLevel)
                    
                    // Add to Christmas List Button
                    Button(action: {
                        // Add action here
//                        dismiss()
                        
                        if (!validateNewItemInput()) {
                            viewStore.dispatch(ListActions.updateItem(itemDetails: NewItemDetails(itemName: itemInContext.name,
                                                                                                  itemDescription: itemInContext.description,
                                                                                                  itemLink: productURL,
                                                                                                  itemPrice: Double(price) ?? 0.00,
                                                                                                  itemQuantity: quantity,
                                                                                                  itemPriority: priorityLevel.rawValue,
                                                                                                  itemId: itemInContext.id),
                                                                      listInContext: self.listInContext))
                        }
                        
                    }) {
                        if (viewStore.state.isLoading) {
                            TextTypingIndicator()
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(.gray)
                                .cornerRadius(16)
                        } else {
                            HStack {
                                Image(systemName: "plus")
                                Text("Update item details")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(.primaryRed)
                            .cornerRadius(12)
                        }
                    }//.disabled(self.errorsOnForm)
                    
                    // Cancel Button
//                    Button(action: {
//                        dismiss()
//                    }) {
//                        Text("Cancel")
//                            .font(.headline)
//                            .foregroundColor(.primary)
//                            .frame(maxWidth: .infinity)
//                            .padding(.vertical, 8)
//                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .navigationTitle("Update Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "arrow.left")
                            .foregroundColor(.primary)
                    }
                }
            }
        }.alert("Input Errors", isPresented: $showingErrorDialog) {
            // Define alert actions (buttons) here
            Button("OK") {}
        } message: {
            Text("Please correct the errors on the form and re-submit.")
        }.overlay(
            Group {
                if viewStore.state.updateItemSuccess  {
                    AnimatedCheckmarkView()
                        .onAppear {
                            Timer.scheduledTimer(withTimeInterval: 4.0, repeats: false) { _ in
                                Task { @MainActor in
                                    dismiss()
                                    viewStore.dispatch(ListActions.updateItemFlowComplete)
                                }
                            }
                        }
                }
            }
        )
    }
    
    private func validateNewItemInput() -> Bool {
        
        // Validate item URL
        if let _ = URL(string: productURL)  {
            itemURLFieldContainsError = false
        } else {
            itemURLFieldContainsError = true
        }
        
        // Validate item price
        if price.containsNonNumericOrPeriod() || price.isEmpty {
            itemPriceFieldContainsError = true
        } else {
            itemPriceFieldContainsError = false
        }
        
        let errorExists = itemURLFieldContainsError || itemPriceFieldContainsError
        
        if errorExists {
            showingErrorDialog = true
        }
        
        return errorExists
        
    }
    
    
    struct ItemNameView: View {
        var itemName: String
        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 2) {
                    Text("Item Name")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text("*")
                        .foregroundColor(.red)
                }
                
                TextField("What would you like for Christmas?", text: .constant(itemName))
                    .border(.clear)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 14)
                    .background(.secondaryAccent)
                    .cornerRadius(8)
                    .disabled(true)
            }
        }
    }
    
    struct DescriptionView: View {
        var itemDescription: String
        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text("Description")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                TextEditor(text: .constant(itemDescription))
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 80)
                    .padding(12)
                    .background(.secondaryAccent)
                    .cornerRadius(8)
                    .disabled(true)
            }
        }
    }
    
    struct ItemURLEntryView : View {
        @Binding var productURL: String
        @Binding var fieldInErrorState: Bool
        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Item URL")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if (fieldInErrorState) {
                        Spacer()
                        Text ("Please enter a valid URL")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
                
                HStack {
                    TextField("https://example.com/product", text: $productURL)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                        .keyboardType(.URL)
                    
                    Button(action: {
                        if let url = URL(string: productURL) {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        Image(systemName: "arrow.up.forward.square")
                            .foregroundColor(.red)
                            .font(.title3)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 14)
                .background(.secondaryAccent)
                .cornerRadius(8)
                .border(fieldInErrorState ? .primaryRed: .clear)
            }
        }
    }
    
    struct ItemPriceEntryView: View {
        @Binding var price: String
        @Binding var fieldInErrorState: Bool
        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text("Price")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                HStack {
                    Text("$")
                        .foregroundColor(.gray)
                    TextField("0.00", text: $price)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.decimalPad)
                    
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 14)
                .background(.secondaryAccent)
                .cornerRadius(8)
                .border(fieldInErrorState ? .primaryRed: .clear)
            }
        }
    }
    
    struct ItemQuantityEntryView: View {
        @Binding var quantity: Int
        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text("Quantity")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                HStack {
                    Button(action: {
                        if quantity > 1 {
                            quantity -= 1
                        }
                    }) {
                        Image(systemName: "minus")
                            .foregroundColor(.gray)
                            .frame(width: 44, height: 44)
                    }
                    
                    Spacer()
                    
                    Text("\(quantity)")
                        .font(.body)
                        .frame(minWidth: 50)
                        .frame(minHeight: 30)
                        .background(Color.background)
                        .cornerRadius(4)
                    
                    Spacer()
                    
                    Button(action: {
                        quantity += 1
                    }) {
                        Image(systemName: "plus")
                            .foregroundColor(.gray)
                            .frame(width: 44, height: 44)
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 9)
                .background(.secondaryAccent)
                .cornerRadius(8)
            }
        }
    }
    
    struct ItemPriorityEntryView: View {
        @Binding var priorityLevel: PriorityLevel
        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 2) {
                    Text("Priority Level")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text("*")
                        .foregroundColor(.red)
                }
                
                HStack(spacing: 12) {
                    ForEach(PriorityLevel.allCases, id: \.self) { priority in
                        Button(action: {
                            priorityLevel = priority
                        }) {
                            VStack(spacing: 12) {
                                Circle()
                                    .fill(priority.color)
                                    .frame(width: 50, height: 50)
                                
                                Text(priority.title)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text(priority.subtitle)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(priorityLevel == priority ? Color.blue : Color.clear, lineWidth: 2)
                            )
                            .background(.secondaryAccent)
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
    
    struct EditItemViewState: Equatable {
        let isLoading: Bool
        let error: ListError?
        let updateItemSuccess: Bool
    }
}

#Preview {
    EditItemView(store: StoreEnvironmentKey.defaultValue, item: MockData.sampleItemDetail, listInContext: "123")
}

#Preview {
    EditItemView(store: StoreEnvironmentKey.defaultValue, item: MockData.sampleItemDetail, listInContext: "123")
        .preferredColorScheme(.dark)
}
