//
//  PurchaseSheetView.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 10/21/25.
//
import SwiftUI

struct PurchaseItemView: View {
    var store: Store<AppState>
    @StateObject private var viewStore: ViewStore<PurchaseSheetViewState>
    @Environment(\.dismiss) var dismiss
    @State private var quantity: Int = 1
    @State private var purchasePrice: String = "0.00"
    @State private var selectedTab: PurchaseTab = .purchase
    @State private var shouldShowPriceView: Bool = true
    @State private var showingPurchaseError: Bool = false
    var item: ItemDetails
    var listInContext: String
    
    enum PurchaseTab {
        case purchase
        case undoPurchase
    }
    
    init(store: Store<AppState>, item: ItemDetails, listInContext: String) {
        self.store = store
        self.item = item
        self.listInContext = listInContext
        self.selectedTab = item.retractablePurchase ? .undoPurchase : .purchase
        self.shouldShowPriceView = item.retractablePurchase ? false : true
        self._viewStore = StateObject(wrappedValue: ViewStore(
            store: store,
            observe: { appState in
                PurchaseSheetViewState(
                    isLoading: appState.list.isLoading,
                    error: appState.list.error,
                    purchaseSuccess: appState.list.purchaseSuccess,
                    retractedPurchaseSuccess: appState.list.retractedPurchaseSuccess
                )
            }
        ))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Drag Indicator (iOS style)
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 8)
                .padding(.bottom, 16)
            
            // Header
            SheetHeaderView(purchaseState: item.purchaseState)
                .padding(.horizontal, 8)
                .padding(.top, 10)
                .padding(.bottom, 20)
            
            VStack(spacing: 24) {
                // Item Card
                ItemHeaderView(item: item)
                
                // Tab Selector (Purchase/Undo Purchase)
                TabButtonView(shouldShowUndoPurchase: item.retractablePurchase, selectedTab: $selectedTab, shouldShowPriceView: $shouldShowPriceView)
                if (shouldShowPriceView) {
                    HStack {
                        // Quantity Section
                        PurchaseQuantityView(item: item, quantity: $quantity)
                        // Purchase Price Section
                        PurchasePriceView(item: item, purchasePrice: $purchasePrice)
                    }
                }
            }
            .padding(.horizontal, 20)
            
            Spacer()
            
            // Confirm Button
            Button(action: {
                // Handle purchase confirmation
                
                if (shouldShowPriceView) {
                    viewStore.dispatch(ListActions.purchaseItem(listInContext: listInContext, itemId: item.id, quantityPurchased: quantity, purchasePrice: Double(purchasePrice) ?? 0.0))
                } else {
                    viewStore.dispatch(ListActions.retractItem(listId: listInContext, itemId: item.id))
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
                    Text(shouldShowPriceView ? "Confirm" : "Undo")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(.green)
                        .cornerRadius(16)
                }
                
            }
            .disabled(viewStore.state.isLoading)
            .padding(.horizontal, 20)
        }
        .alert("Purchase Failed", isPresented: $showingPurchaseError) {
            Button("OK") {
                viewStore.dispatch(ListActions.purchaseFlowComplete)
            }
        } message: {
            Text("Unable to mark this item as purchased. Please try again later.")
        }
        .onAppear {
            // CRITICAL: Update viewStore with environment store
            viewStore.updateStore(store)
        }
        .background(Color(UIColor.systemGray6))
        .overlay(
            Group {
                if viewStore.state.purchaseSuccess || viewStore.state.retractedPurchaseSuccess {
                    AnimatedCheckmarkView()
                        .onAppear {
                            Timer.scheduledTimer(withTimeInterval: 4.0, repeats: false) { _ in
                                Task { @MainActor in
                                    dismiss()
                                    viewStore.dispatch(ListActions.purchaseFlowComplete)
                                }
                            }
                        }
                } else if viewStore.state.error != nil {
                    AnimatedErrorView()
                        .onAppear {
                            Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
                                Task { @MainActor in
                                    showingPurchaseError = true
                                }
                            }
                        }
                }
            }
        )
    }
    
    struct ItemHeaderView: View {
        let item: ItemDetails
        
        var body: some View {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.red)
                        .frame(width: 40, height: 40)
                    Image(systemName: "gift.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                }
                
                Text(item.name)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.black)
                
                Spacer()
            }
            .padding(20)
            .background(Color.white)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
    }
    
    struct TabButtonView: View {
        @State var shouldShowUndoPurchase: Bool
        @Binding var selectedTab: PurchaseTab
        @Binding var shouldShowPriceView: Bool
        
        var body: some View {
            HStack(spacing: 12) {
                Button(action: {
                    withAnimation(.bouncy(duration: 0.5)) {
                        selectedTab = .purchase
                        shouldShowPriceView = true
                    }
                }) {
                    Text("Purchase")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(selectedTab == .purchase ? .black : .gray)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(selectedTab == .purchase ? Color.white : Color.clear)
                        .cornerRadius(12)
                        .padding(shouldShowUndoPurchase ? EdgeInsets() : EdgeInsets(top: 0, leading: 24, bottom: 0, trailing: 24))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.2), lineWidth: selectedTab == .purchase ? 1 : 0)
                        )
                }.disabled(!shouldShowUndoPurchase)
                
                if (shouldShowUndoPurchase) {
                    Button(action: {
                        withAnimation(.bouncy(duration: 0.5)) {
                            selectedTab = .undoPurchase
                            shouldShowPriceView = false
                        }
                    }) {
                        Text("Undo Purchase")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(selectedTab == .undoPurchase ? .black : .gray)
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .background(selectedTab == .undoPurchase ? Color.white : Color.clear)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: selectedTab == .undoPurchase ? 1 : 0)
                            )
                    }
                }
            }
            .padding(4)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(14)
        }
    }
    
    struct SheetHeaderView: View {
        let purchaseState: PurchaseState
        
        var body: some View {
            VStack {
                Text("Manage Purchase")
                    .font(.system(size: 20, weight: .bold))
                
                switch purchaseState {
                case .available:
                    EmptyView()
                case .unavailable:
                    Text("The requested number of items have already been purchased")
                        .font(Font.system(size: 12, weight: .thin))
                case .partial:
                    Text("Someone else has purchased some of this item.")
                        .font(Font.system(size: 12, weight: .thin))
                case .purchased:
                    Text("You have already purchased this item. You can undo your purchase.")
                        .font(Font.system(size: 12, weight: .thin))
                }
                
                
            }
        }
    }
    
    struct PurchaseQuantityView: View {
        let item: ItemDetails
        @Binding var quantity: Int
        
        var body: some View {
            VStack(alignment: .leading) {
                Text("Quantity")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black)
                Text("\(item.quantity) requested")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(.black)
                
                HStack {
                    Button(action: {
                        if quantity > 1 { quantity -= 1 }
                    }) {
                        Image(systemName: "minus")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.gray)
                            .frame(width: 40, height: 40)
                            .background(Color.gray.opacity(0.1))
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    Text("\(quantity)")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.black)
                    
                    Spacer()
                    
                    Button(action: {
                        quantity += 1
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.gray)
                            .frame(width: 40, height: 40)
                            .background(Color.gray.opacity(0.1))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(Color.white)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
            }
        }
    }
    
    struct PurchasePriceView: View {
        let item: ItemDetails
        @Binding var purchasePrice: String
        
        var body: some View {
            VStack(alignment: .leading) {
                Text("Purchase Price")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black)
                
                Text("List price: $\(String(format: "%.2f", item.price))")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(.black)
                
                HStack(spacing: 12) {
                    Text("$")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.gray)
                    
                    TextField("0.00", text: $purchasePrice)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.gray)
                        .keyboardType(.decimalPad)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
                .background(Color.white)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
            }
        }
    }
}

struct TextTypingIndicator: View {
    @State private var opacity = false
    var body: some View {
        HStack {
            Text("Saving")
            ForEach(0..<5) { i in
                Circle()
                    .frame(width: 5, height: 5)
                    .opacity(opacity ? 1 : 0.3)
                    .animation(.easeInOut(duration: 0.6).repeatForever().delay(Double(i) * 0.2), value: opacity)
            }
        }
        .onAppear { opacity.toggle()
        }
    }
}

struct PurchaseSheetViewState: Equatable {
    let isLoading: Bool
    let error: ListError?
    let purchaseSuccess: Bool
    let retractedPurchaseSuccess: Bool
}

#Preview {
    PurchaseItemView(store: StoreEnvironmentKey.defaultValue, item: MockData.sampleItemDetail, listInContext: "123")
}

#Preview {
    PurchaseItemView(store: StoreEnvironmentKey.defaultValue, item: MockData.sampleItemDetail, listInContext: "123")
        .preferredColorScheme(.dark)
}
