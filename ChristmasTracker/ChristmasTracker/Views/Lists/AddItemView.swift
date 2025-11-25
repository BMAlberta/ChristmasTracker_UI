//
//  AddItemView.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 10/17/25.
//

import SwiftUI

struct AddNewItemView: View {
    @Environment(\.dismiss) var dismiss
    var store: Store<AppState>
    @StateObject private var viewStore: ViewStore<AddNewItemViewState>
    @State private var showingErrorDialog: Bool = false
    @State private var itemName: String = ""
    @State private var itemDescription: String = ""
    @State private var productURL: String = ""
    @State private var price: String = ""
    @State private var quantity: Int = 1
    @State private var priorityLevel: PriorityLevel = .medium
    @State private var itemNameFieldContainsError = false
    @State private var itemURLFieldContainsError = false
    @State private var itemPriceFieldContainsError = false
    
    
    var errorsOnForm: Bool {
        return itemNameFieldContainsError || itemURLFieldContainsError || itemPriceFieldContainsError
    }
    
    
    init(store: Store<AppState>) {
        self.store = store
        self._viewStore = StateObject(wrappedValue: ViewStore(
            store: store,
            observe: { appState in
                return AddNewItemViewState(
                    isLoading: appState.list.isLoading,
                    error: appState.list.error,
                    listInContext: appState.list.listIdInContext,
                    addItemSuccess: appState.list.addItemSuccess
                )
            }
        ))
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Item Name
                    ItemNameView(itemName: $itemName, fieldInErrorState: $itemNameFieldContainsError)
                    
                    // Description
                    DescriptionView(itemDescription: $itemDescription)
                    
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
                        if (!validateNewItemInput()) {
                            viewStore.dispatch(ListActions.addItem(newItemDetails:
                                                                    NewItemDetails(itemName: itemName,
                                                                                   itemDescription: itemDescription,
                                                                                   itemLink: productURL,
                                                                                   itemPrice: Double(price) ?? 0.00,
                                                                                   itemQuantity: quantity,
                                                                                   itemPriority: priorityLevel.rawValue,
                                                                                   itemImageUrl: nil,
                                                                                   itemId: nil),
                                                                   listInContext: viewStore.state.listInContext))
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
                                Text("Add to Christmas List")
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
            .navigationTitle("Add New Item")
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
                if viewStore.state.addItemSuccess  {
                    AnimatedCheckmarkView()
                        .onAppear {
                            Timer.scheduledTimer(withTimeInterval: 4.0, repeats: false) { _ in
                                Task { @MainActor in
                                    dismiss()
                                    viewStore.dispatch(ListActions.addItemFlowComplete)
                                }
                            }
                        }
                }
            }
        )
    }
    
    private func validateNewItemInput() -> Bool {
        
        // Validate item name
        if itemName.isEmpty {
            itemNameFieldContainsError = true
        } else {
            itemNameFieldContainsError = false
        }
        
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
        
        let errorExists = itemNameFieldContainsError || itemURLFieldContainsError || itemPriceFieldContainsError
        
        if errorExists {
            showingErrorDialog = true
        }
        
        return errorExists
    }
    
    
    struct ItemNameView: View {
        @Binding var itemName: String
        @Binding var fieldInErrorState: Bool
        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 2) {
                    Text("Item Name")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text("*")
                        .foregroundColor(.red)
                }
                
                TextField("What would you like for Christmas?", text: $itemName)
                    .textFieldStyle(.roundedBorder)
                    .border(fieldInErrorState ? .primaryRed: .clear)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 14)
                    .background(.secondaryAccent)
                    .cornerRadius(8)
            }
        }
    }
    
    struct DescriptionView: View {
        var characterLimit = 255
        @Binding var itemDescription: String
        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment:.center) {
                    Text("Description")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text("(\(itemDescription.count)/\(characterLimit))")
                                    .font(.caption)
                                    .foregroundColor(itemDescription.count >= characterLimit ? .red : .gray)
                }
                
    
                TextEditor(text: $itemDescription)
                    .frame(minHeight: 80)
                    .padding(12)
                    .background(.secondaryAccent)
                    .cornerRadius(8)
                    .onChange(of: itemDescription) { oldValue, newValue in
                        if newValue.count > characterLimit {
                            itemDescription = String(newValue.prefix(characterLimit))
                        }
                    }
                    .overlay(
                        Group {
                            if itemDescription.isEmpty {
                                Text("Add more details about this item...")
                                    .foregroundColor(.gray)
                                    .padding(.leading, 16)
                                    .padding(.top, 20)
                                    .allowsHitTesting(false)
                            }
                        },
                        alignment: .topLeading
                    )
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
//                    TextField("https://example.com/product", text: $productURL)
                    TextField("https://example.com/product", text: Binding(
                                    get: { self.productURL },
                                    set: { newValue in
                                        self.productURL = newValue
                                        // Attempt to find a URL within the pasted string and update the URL object
                                        self.extractURL(from: newValue)
                                    }
                                ))
                        .textFieldStyle(.plain)
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
        
        func extractURL(from input: String) {
                // Use NSDataDetector for robust URL detection in the string
                let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
                let matches = detector?.matches(in: input, options: [], range: NSRange(location: 0, length: input.utf16.count))

                // Get the first detected URL
                if let firstMatch = matches?.first, let range = Range(firstMatch.range, in: input) {
                    let extractedURLString = String(input[range])
                     self.productURL = extractedURLString
                } else {
                    self.productURL = ""
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
                        .keyboardType(.decimalPad)
                        .onChange(of: price) { oldValue, newValue in
                            let filtered = newValue.filter { "0123456789.".contains($0) }
                            if filtered != newValue {
                                price = filtered
                            }
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
                        .frame(minWidth: 30)
                    
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
    
    struct AddNewItemViewState: Equatable {
        let isLoading: Bool
        let error: ListError?
        let listInContext: String
        let addItemSuccess: Bool
    }
}

#Preview {
    AddNewItemView(store: StoreEnvironmentKey.defaultValue)
}

#Preview {
    AddNewItemView(store: StoreEnvironmentKey.defaultValue)
        .preferredColorScheme(.dark)
}
