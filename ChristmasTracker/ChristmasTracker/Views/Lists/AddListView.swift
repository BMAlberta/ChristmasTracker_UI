//
//  AddListView.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 10/17/25.
//

import SwiftUI

struct AddListView: View {
    @Environment(\.dismiss) var dismiss
    var store: Store<AppState>
    @StateObject private var viewStore: ViewStore<AddListViewState>
    @State private var showingErrorDialog: Bool = false
    @State private var listName: String = ""
    @State private var listTheme: String = ""
    @State private var listNameFieldContainsError = false
    
    init(store: Store<AppState>) {
        self.store = store
        self._viewStore = StateObject(wrappedValue: ViewStore(
            store: store,
            observe: { appState in
                return AddListViewState(
                    isLoading: appState.list.isLoading,
                    error: appState.list.error,
                    addListSuccess: appState.list.addListSuccess
                )
            }
        ))
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Item Name
                    ListNameView(listName: $listName, fieldInErrorState: $listNameFieldContainsError)
                    
                    // Description
                    ListThemeView(listTheme: $listTheme)
                    
                    // Add to Christmas List Button
                    Button(action: {
                        // Add action here
                        if (!validateNewListInput()) {
                            viewStore.dispatch(ListActions.addList(newListDetails: NewListDetails(listName: listName, listTheme: listTheme)))
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
                                Text("Create List")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(.primaryRed)
                            .cornerRadius(12)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .navigationTitle("Create New List")
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
                if viewStore.state.addListSuccess  {
                    AnimatedCheckmarkView()
                        .onAppear {
                            Timer.scheduledTimer(withTimeInterval: 4.0, repeats: false) { _ in
                                Task { @MainActor in
                                    dismiss()
                                    viewStore.dispatch(ListActions.addListFlowComplete)
                                }
                            }
                        }
                }
            }
        )
    }
    
    private func validateNewListInput() -> Bool {
            
        // Validate item name
        if listName.isEmpty {
            listNameFieldContainsError = true
        } else {
            listNameFieldContainsError = false
        }
        
        
        let errorExists = listNameFieldContainsError
        
        if errorExists {
            showingErrorDialog = true
        }
        
        return errorExists
        
    }
    
    
    struct ListNameView: View {
        @Binding var listName: String
        @Binding var fieldInErrorState: Bool
        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 2) {
                    Text("List Name")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text("*")
                        .foregroundColor(.red)
                }
                
                TextField("Give your list a creative name", text: $listName)
                    .textFieldStyle(.roundedBorder)
                    .border(fieldInErrorState ? .primaryRed: .clear)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 14)
                    .foregroundColor(.gray)
                    .background(.secondaryAccent)
                    .cornerRadius(8)
            }
        }
    }
    
    struct ListThemeView: View {
        @Binding var listTheme: String
        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text("List Theme")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                TextEditor(text: $listTheme)
                    .frame(minHeight: 80)
                    .padding(12)
                    .background(.secondaryAccent)
                    .cornerRadius(8)
                    .overlay(
                        Group {
                            if listTheme.isEmpty {
                                Text("Add more details about your list to help others...")
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
    
    struct AddListViewState: Equatable {
        let isLoading: Bool
        let error: ListError?
        let addListSuccess: Bool
    }
}
//struct AddListView_Previews: PreviewProvider {
//    static var previews: some View {
//        Group {
//            AddListView(store: StoreEnvironmentKey.defaultValue) // Default (light mode)
//            AddListView(store: StoreEnvironmentKey.defaultValue)
//                .preferredColorScheme(.dark) // Dark mode
//        }
//    }
//}


#Preview {
    AddListView(store: StoreEnvironmentKey.defaultValue) // Default (light mode)
}

#Preview {
    AddListView(store: StoreEnvironmentKey.defaultValue) // Default (light mode)
        .preferredColorScheme(.dark)
}
