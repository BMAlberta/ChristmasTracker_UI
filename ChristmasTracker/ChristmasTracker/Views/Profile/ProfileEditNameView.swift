//
//  ProfileEditNameView.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 10/27/25.
//

import SwiftUI


struct ProfileEditNameView: View {
    @Environment(\.dismiss) var dismiss
    var store: Store<AppState>
    @StateObject private var viewStore: ViewStore<ProfileEditNameViewState>
    @State private var showingErrorDialog: Bool = false
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var firstNameFieldContainsError = false
    @State private var lastNameFieldContainsError = false
    
    init(store: Store<AppState>) {
        self.store = store
        self._viewStore = StateObject(wrappedValue: ViewStore(
            store: store,
            observe: { appState in
                return ProfileEditNameViewState(
                    isLoading: appState.user.isLoading,
                    error: appState.user.error,
                    nameEditSuccessful: appState.user.updateNameSuccess,
                    userIdInContext: appState.user.currentUser?.id ?? ""
                )
            }
        ))
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Item Name
                    EditNameView(type: .firstName, name: $firstName, fieldInErrorState: $firstNameFieldContainsError)
                    
                    // Description
                    EditNameView(type: .lastName, name: $lastName, fieldInErrorState: $lastNameFieldContainsError)
                    
                    // Add to Christmas List Button
                    Button(action: {
                        // Add action here
                        if (!validateNewListInput()) {
                            viewStore.dispatch(UserActions.updateProfileName(userId: viewStore.state.userIdInContext, firstName: firstName, lastName: lastName))
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
                                Image(systemName: "square.and.arrow.up")
                                Text("Update profile")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(.primaryGreen)
                            .cornerRadius(12)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .navigationTitle("Edit Name")
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
                if viewStore.state.nameEditSuccessful  {
                    AnimatedCheckmarkView()
                        .onAppear {
                            Timer.scheduledTimer(withTimeInterval: 4.0, repeats: false) { _ in
                                Task { @MainActor in
                                    dismiss()
                                    viewStore.dispatch(UserActions.updateProfileFlowComplete)
                                }
                            }
                        }
                }
            }
        )
    }
    
    private func validateNewListInput() -> Bool {
            
        // Validate first name
        if firstName.isEmpty {
            firstNameFieldContainsError = true
        } else {
            firstNameFieldContainsError = false
        }
        
        // Validate last name
        if lastName.isEmpty {
            lastNameFieldContainsError = true
        } else {
            lastNameFieldContainsError = false
        }
        
        
        let errorExists = firstNameFieldContainsError || lastNameFieldContainsError
        
        if errorExists {
            showingErrorDialog = true
        }
        
        return errorExists
        
    }
    
    
    struct EditNameView: View {
        var type: ProfileSettingsFieldType
        @Binding var name: String
        @Binding var fieldInErrorState: Bool

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 2) {
                    Text(type.fieldTitle)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text("*")
                        .foregroundColor(.red)
                }
                
                TextField(type.fieldPlaceholder, text: $name)
                    .textFieldStyle(.roundedBorder)
                    .border(fieldInErrorState ? .primaryRed: .clear)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 14)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            }
        }
    }
    
    
    struct ProfileEditNameViewState: Equatable {
        let isLoading: Bool
        let error: UserError?
        let nameEditSuccessful: Bool
        let userIdInContext: String
    }
}


#Preview {
    ProfileEditNameView(store: StoreEnvironmentKey.defaultValue) // Default (light mode)
}

#Preview {
    ProfileEditNameView(store: StoreEnvironmentKey.defaultValue) // Default (light mode)
        .preferredColorScheme(.dark)
}


enum ProfileSettingsFieldType: CaseIterable {
    case firstName
    case lastName
    
    var fieldTitle: String {
        switch self {
        case .firstName: return "First Name"
        case .lastName: return "Last Name"
        }
    }
    
    var fieldPlaceholder: String {
        switch self {
        case .firstName: return "Enter your first name"
        case .lastName: return "Enter your last name"
        }
    }
}



