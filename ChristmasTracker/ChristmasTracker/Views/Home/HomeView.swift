//
//  HomeView.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 10/4/25.
//

import SwiftUI

struct HomeView: View {
    private var store: Store<AppState>
    @StateObject private var viewStore: ViewStore<HomeViewState>
    @State private var path = NavigationPath()
    @State private var showDetail = false
    @State private var showingAddList = false
    @State private var showingJoinList = false
    @State private var selectedFilter: FilterItem = .all
    @State private var listInContext: String = ""
    
    init(store: Store<AppState>) {
        self.store = store
        self._viewStore = StateObject(wrappedValue: ViewStore(
            store: store,
            observe: { appState in
                HomeViewState(
                    isLoading: appState.list.isLoading,
                    teaser: appState.user.teaser,
                    lists: appState.list.listSummaries,
                    loggedInUser: appState.user.currentUser?.id ?? ""
                )
            }
        ))
    }
    
    var filteredAndSortedLists: [ListSummary] {
        var result = viewStore.state.lists
        
        // Apply filter
        switch selectedFilter {
        case .all:
            break
        case .myLists:
            result = result.filter { $0.ownerInfo.id == viewStore.state.loggedInUser }
        case .joined:
            result = result.filter { $0.ownerInfo.id != viewStore.state.loggedInUser }
        case .active:
            result = result.filter { $0.status != .archive }
        case .archived:
            result = result.filter { $0.status == .archive }
        }
        
        return result
    }
    
    
    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                List {
                    TeaserView(teaser: viewStore.state.teaser)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    
                    HomeFeedButtonGroup(onNewList: {
                        showingAddList = true
                    }, onJoinList: {
                        showingJoinList = true
                    })
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    
                    FilterCarouselView(selectedFilter: $selectedFilter) { selectedFilter in
                        print("Selected filter: \(selectedFilter.rawValue)")
                        self.selectedFilter = selectedFilter
                        
                    }
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .contentMargins(.leading, 20, for: .scrollContent)
                    
                    if (filteredAndSortedLists.isEmpty) {
                        Text("No Lists Available")
                            .font(.brandFont(size: 22))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .padding(EdgeInsets(top: 0, leading: 0, bottom: -32, trailing: 0))
                    } else {
                        ForEach(filteredAndSortedLists, id: \.self.id) { listSummary in
                            NavigationLink(value: listSummary) {
                                ListSummaryTile(listSummary: listSummary)
                            }.buttonStyle(PlainButtonStyle())
                                .navigationLinkIndicatorVisibility(.hidden)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .gesture(TapGesture().onEnded({
                                    Task {
                                        viewStore.dispatch(ListActions.viewListDetails(listSummary.id))
                                        self.listInContext = listSummary.id
                                        self.showDetail = true
                                    }
                                }))
                        }
                    }
                    
                    Text("Recent Activity")
                        .font(.brandFont(size: 22))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .padding(EdgeInsets(top: 0, leading: 0, bottom: -32, trailing: 0))
                    
                    ActivityListView(store: store)
                        .background(.white)
                        .cornerRadius(6)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    
                }
                .padding(EdgeInsets(top: 0, leading: -20, bottom: 0, trailing: -20))
                .navigationDestination(isPresented: $showDetail, destination: {
                    ListDetail(store: store)
                })
                
                if viewStore.state.isLoading {
                    Color.black.opacity(0.65) // Semi-transparent background
                        .edgesIgnoringSafeArea(.all) // Extend over safe areas
                    
                    ProgressView("Loading...") // Your loading indicator
                        .progressViewStyle(CircularProgressViewStyle(tint: .primaryRed))
                        .controlSize(.large)
                        .foregroundColor(.white)
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.8)))
                }
            }
        }
        .alert("Currently Unavailable", isPresented: $showingJoinList) {
            // Define alert actions (buttons) here
            Button("OK") {}
        } message: {
            Text("The join list functionality is currently unavailable. Please try again later.")
        }
        .onAppear {
            // CRITICAL: Update viewStore with environment store
            viewStore.updateStore(store)
        }
        .sheet(isPresented: $showingAddList) {
            AddListView(store: store)
                .presentationBackground(Color.background)
                .presentationDetents([.medium])
        }
    }
}

struct HomeViewState: Equatable {
    let isLoading: Bool
    let teaser: Teaser
    let lists: [ListSummary]
    let loggedInUser: String
}

#Preview {
    HomeView(store: StoreEnvironmentKey.defaultValue)
}

#Preview {
    HomeView(store: StoreEnvironmentKey.defaultValue)
        .preferredColorScheme(.dark)
}
