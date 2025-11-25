//
//  TempListView_Custom.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 10/17/25.
//

import SwiftUI
import LinkPresentation
import UniformTypeIdentifiers.UTType

// MARK: - Filter & Sort Options

enum FilterOptions: String, CaseIterable {
    case all = "All"
    case available = "Available"
    case purchased = "Purchased"
    case pending = "Unavailable"
    case partial = "Partial"
}

enum SortOptions: String, CaseIterable {
    case name = "Name"
    case price = "Price"
    case priority = "Priority"
    case status = "Status"
}

// MARK: - ListDetail View -

struct ListDetail: View {
    @State private var showingAddItem = false
    @State private var showingFilter = false
    @State private var showingSort = false
    @State private var showingDeleteConfirmation = false
    @State private var itemIndexToDelete: IndexSet = IndexSet()
    @State private var selectedFilter: FilterOptions = .all
    @State private var selectedSort: SortOptions = .name
    @State private var searchText: String = ""
    @State private var searchActive: Bool = false
    let id = UUID()
    
    var items: [GridItem] {
        Array(repeating: .init(.adaptive(minimum: 300)), count: 1)
    }
    
    @Environment(\.isSearching) private var isSearching
    @Environment(\.dismiss) var dismiss
    
    private var store: Store<AppState>
    @StateObject private var viewStore: ViewStore<ListDetailViewState>
    
    init(store: Store<AppState>) {
        self.store = store
        self._viewStore = StateObject(wrappedValue: ViewStore(
            store: store,
            observe: { appState in
                let listIndex = ListUtility.mapIdToIndex(id: appState.list.listIdInContext, appState: appState)
                return ListDetailViewState(
                    isLoading: appState.list.isLoading,
                    teaser: appState.user.teaser,
                    listInContext: appState.list.listSummaries[listIndex],
                    error: appState.list.error
                )
            }
        ))
    }
    
    var filteredAndSortedItems: [ItemDetails] {
        var result = viewStore.state.listInContext.items
        
        // Apply filter
        switch selectedFilter {
        case .all:
            break
        case .purchased:
            result = result.filter { $0.purchaseState == .purchased }
        case .pending:
            result = result.filter { $0.purchaseState == .unavailable }
        case .partial:
            result = result.filter { $0.purchaseState == .partial }
        case .available:
            result = result.filter { $0.purchaseState == .available }
        }
        
        // Apply sort
        switch selectedSort {
        case .name:
            result.sort { $0.name < $1.name }
        case .price:
            result.sort { $0.price < $1.price }
        case .status:
            if (viewStore.state.listInContext.canViewMetadata) {
                result.sort { $0.purchaseState.rawValue < $1.purchaseState.rawValue }
            } else {
                result.sort { $0.name < $1.name }
            }
        case .priority:
            result.sort { $0.priority?.rawValue ?? 3 < $1.priority?.rawValue ?? 3 }
        }
        return result
    }
    
//    var purchasedCount: Int {
//        items.filter { $0.quantityPurchased }.count
//    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header section
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(viewStore.state.listInContext.listTheme)
                        .font(.brandFont(size: 12))
                        .fontWeight(.light)
                    
                    Spacer()
                    
                    Button(action: { showingAddItem = true
                    }) {
                        Label("Add Item", systemImage: "plus")
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(.primaryRed)
                            .cornerRadius(8)
                    }
                }
                
                HStack {
                    Text(quantityString)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if (viewStore.state.listInContext.canViewMetadata) {
                        Button(action: { showingFilter = true }) {
                            Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                                .font(.brandFont(size: 18))
                        }
                    }
                    Button(action: { showingSort = true }) {
                        Label("Sort", systemImage: "arrow.up.arrow.down")
                            .font(.brandFont(size: 18))
                    }
                }
                .padding(EdgeInsets(top: 16, leading: 0, bottom: 0, trailing: 0))
            }
            .padding()
            
            Divider()
    
            // List of items
            List {
                ForEach(filteredAndSortedItems, id: \.id) { item in
                    ItemDetailRow(store: store, itemId: item.id, listInContext: viewStore.state.listInContext.id)
                        .deleteDisabled(!item.deleteAllowed)
                        .buttonStyle(PlainButtonStyle())
                        .listRowBackground(
                            Rectangle()
                                .fill(Color.background)
                                 
                                 .padding(EdgeInsets(top: 12, leading: 0, bottom: 12, trailing: 0))
                                 .cornerRadius(4)
                        )
                        .listRowSeparator(.hidden)
                }
                .onDelete(perform: { item in
                    itemIndexToDelete = item
                    showingDeleteConfirmation = true
                })
            }
            .listStyle(.insetGrouped)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(viewStore.state.listInContext.name)
                    .font(.headline)
            }
            
            
            
            
//            if (viewStore.state.listInContext.canViewMetadata) {
//                ToolbarItem(placement: .navigationBarTrailing) {
//                    HStack {
//                        Button(action: {
//                            searchActive.toggle()
//                        }) {
//                            Image(systemName: "magnifyingglass")
//                        }
//                        Button(action: {}) {
//                            Image(systemName: "ellipsis")
//                        }
//                    }
//                }
//            }
        }
        .sheet(isPresented: $showingAddItem) {
            AddNewItemView(store: store)
        }
        .confirmationDialog("Do you really want to delete this item?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible, presenting: itemIndexToDelete, actions: { item in
                    Button("Delete Item", role: .destructive) {
                        withAnimation {
                            let index = item[item.startIndex]
                            let itemInContext = self.filteredAndSortedItems[index]
                            viewStore.dispatch(ListActions.deleteItem(itemId: itemInContext.id,
                                                                      listId: viewStore.state.listInContext.id))
                        }
                    }
                })
        .confirmationDialog("Filter Items", isPresented: $showingFilter) {
            ForEach(FilterOptions.allCases, id: \.self) { option in
                Button(option.rawValue) {
                    selectedFilter = option
                }
            }
        }
        .confirmationDialog("Sort Items", isPresented: $showingSort) {
            ForEach(SortOptions.allCases, id: \.self) { option in
                Button(option.rawValue) {
                    selectedSort = option
                }
            }
        }.alert("Operation Failed", isPresented: .constant(viewStore.state.error != nil)) {
            Button("OK") {
                viewStore.dispatch(ListActions.listErrorsCleared)
            }
        } message: {
            Text("We were unable to complete that action. Please try again later.")
        }
        .onAppear {
            viewStore.updateStore(store)
        }
    }
    
    var quantityString: String {
        if viewStore.state.listInContext.canViewMetadata {
            return "\(viewStore.state.listInContext.totalItems) items • \(viewStore.state.listInContext.purchasedItems) purchased"
        } else {
            return "\(viewStore.state.listInContext.items.count) items"
        }
    }
}

struct ListDetailViewState: Equatable {
    let isLoading: Bool
    let teaser: Teaser
    let listInContext: ListSummary
    let error: ListError?
}


// MARK: - Item Row -

struct ItemDetailRow: View {
    let id = UUID()
    @State var showPurchaseView: Bool = false
    @State var showingEditItem = false

    
    private var store: Store<AppState>
    @StateObject private var viewStore: ViewStore<ItemDetailRowViewState>
    
    init(store: Store<AppState>, itemId: String, listInContext: String) {
        self.store = store
        self._viewStore = StateObject(wrappedValue: ViewStore(
            store: store,
            observe: { appState in
                let listIndex = ListUtility.mapIdToIndex(id: appState.list.listIdInContext, appState: appState)
                let itemIndex = ListUtility.mapItemIdToItemToIndex(itemId: itemId, listIdInContext: appState.list.listIdInContext, appState: appState)
                if appState.list.listSummaries[listIndex].items.count > 0 {
                    return ItemDetailRowViewState(listInContext: appState.list.listSummaries[listIndex],
                                                  itemInContext: appState.list.listSummaries[listIndex].items[itemIndex])
                } else {
                    return ItemDetailRowViewState(listInContext: appState.list.listSummaries[listIndex],
                                                  itemInContext:ItemDetails.defaultItem())
                }
                
            }
        ))
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            LinkPreview(imageUrlString: viewStore.state.itemInContext.imageUrl)
                .frame(width: 60, height: 60)
                .cornerRadius(8)
            
            
            // Item details
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(viewStore.state.itemInContext.name)
                        .font(.headline)
                        .lineLimit(2)
                    Spacer()
                    
                    // Status badge
                    if (viewStore.state.itemInContext.canViewMetadata) {
                        Text(viewStore.state.itemInContext.purchaseState.description)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(viewStore.state.itemInContext.purchaseState.color)
                            .cornerRadius(12)
                    } else {
                        Button(action: {
                            showPurchaseView.toggle()
                        }) {
                            Image(systemName: "square.and.pencil")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Text(viewStore.state.itemInContext.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                Spacer()
                
                HStack {
                    Text("$\(String(format: "%.2f", viewStore.state.itemInContext.price))")
                        .font(.headline)
                        .foregroundColor(.primaryRed)
                    
                    Text(quantityString)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Image(systemName: "star.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(viewStore.state.itemInContext.priority?.tintColor ?? .buttonText)
                        .padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    
                    
                    Spacer()
                    if (viewStore.state.itemInContext.editAllowed) {
                        Button(action: {
                            showingEditItem.toggle()
                        }) {
                            Image(systemName: "slider.horizontal.3")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    
                    Spacer()

                    if (viewStore.state.itemInContext.canViewMetadata) {
                        Button(action: {
                            showPurchaseView.toggle()
                        }) {
                            Image(systemName: "cart")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    
                    Spacer()
                    
                    Button(action: {
                        if let url = URL(string: viewStore.state.itemInContext.link) {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .background(Color.background)
        .padding(.vertical, 8)
        .sheet(isPresented: $showPurchaseView) {
            PurchaseItemView(store: store, item: viewStore.state.itemInContext, listInContext: store.state.list.listIdInContext)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showingEditItem) {
            EditItemView(store: store, item: viewStore.state.itemInContext, listInContext: viewStore.state.listInContext.id)
//                .presentationBackground(.white)
                .presentationDetents([.large])
        }
    }
    
    private var quantityString: String {
        if viewStore.state.itemInContext.canViewMetadata {
            return "Qty: \(viewStore.state.itemInContext.quantityPurchased)/\(viewStore.state.itemInContext.quantity)"
        } else {
            return "Qty: \(viewStore.state.itemInContext.quantity)"
        }
    }
    
    struct ItemDetailRowViewState: Identifiable, Equatable {
        let id = UUID()
        let listInContext: ListSummary
        let itemInContext: ItemDetails
    }
}


struct LinkPreview: View {
    var imageUrlString: String
    
    var body: some View {
            AsyncImage(url: URL(string: imageUrlString)) { phase in
                switch phase {
                case .empty:
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))
                        .overlay(
                            VStack(spacing: 4) {
                                Image(systemName: "link")
                                    .font(.title2)
                                    .foregroundColor(.gray)
                            }
                                .padding(8)
                        )
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit() // Display the loaded image, resized
                        .aspectRatio(contentMode: .fill)
                        .clipped()
                case .failure:
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.primaryRed)
                @unknown default:
                    EmptyView()
                }
            } // Apply modifiers to the entire view
        }
}

// MARK: - Custom Link Preview -

struct CustomLinkPreview: View {
    struct ImageMetadata {
        let tile: String?
        let iconImage: UIImage?
        let linkImage: UIImage?
        let imageURL: URL?
    }
    
    let urlString: String?

    @State private var metadata: ImageMetadata? = nil
    @State private var isLoading = true
    
    var body: some View {
        ZStack {
            if isLoading {
                // Loading state
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.2))
                    .overlay(
                        ProgressView()
                    )
            } else if let uiImage = metadata?.linkImage {
                // Display loaded image
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipped()
            } else {
                // Fallback placeholder
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.2))
                    .overlay(
                        VStack(spacing: 4) {
                            Image(systemName: "link")
                                .font(.title2)
                                .foregroundColor(.gray)
                            if let siteName = metadata?.tile {
                                Text(siteName)
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                                    .lineLimit(1)
                            }
                        }
                            .padding(8)
                    )
            }
        }
        .task {
            guard let metadata = await self.loadMetadata() else {return}
            let icon = await self.getImage(metadata.iconProvider)
            let image = await self.getImage(metadata.imageProvider)
            let title = metadata.title
            self.metadata = ImageMetadata(tile: title, iconImage: icon, linkImage: image, imageURL: metadata.value(forKeyPath: "imageMetadata.URL") as? URL)
            
        }
    }
    
    private func loadMetadata() async -> LPLinkMetadata? {
        let metadataProvider = LPMetadataProvider()
        guard let urlStringToConvert = urlString,
              let url = URL(string: urlStringToConvert) else { return nil }
        do {
            let result = try await metadataProvider.startFetchingMetadata(for: url)
            return result
        } catch(let error) {
            print(error)
            return nil
        }
    }
    
    private func getImage(_ itemProvider: NSItemProvider?) async -> UIImage? {
        
        defer {
            self.isLoading = false
        }
        guard let itemProvider else { return nil }
        let allowedType = UTType.image.identifier
        guard itemProvider.hasItemConformingToTypeIdentifier(allowedType)  else {
            return nil
        }
        do {
            let item =  try await itemProvider.loadItem(forTypeIdentifier: allowedType)
            
            if let url = item as? URL, let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                return image
            }
            
            if let image = item as? UIImage {
                return image
            }
            
            if let data = item as? Data, let image = UIImage(data: data) {
                return image
            }
            
            return nil
            
        } catch (let error) {
            print(error)
            return nil
        }
    }
}


// MARK: - Preview -

#Preview {
    ListDetail(store: StoreEnvironmentKey.defaultValue)
}

#Preview {
    ListDetail(store: StoreEnvironmentKey.defaultValue)
        .preferredColorScheme(.dark)
}
