//
//  UserAccessKeyView.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 11/21/22.
//

import SwiftUI

struct UserAccessKeyView: View {
    
    enum FocusableField: Hashable {
        case firstName
        case lastName
        case email
        case newPassword
        case confirmPassword
        case accessKey
    }
    
    
    @EnvironmentObject var _session: UserSession
    @State private var shouldShowVerificationScreen = false
    @StateObject var viewModel: UserAccessKeyViewModel
    @Environment(\.presentationMode) var presentationMode
    @FocusState private var focus: FocusableField?
    var body: some View {
        NavigationView {
            ZStack {
                VStack {
                    Form {
                        UserInformationView(data: viewModel, focus: _focus)
                        Section("Access Key") {
                            TextField("Access key", text: $viewModel.accessKey)
//                                .focused($focus, equals: .accessKey)
                                .textInputAutocapitalization(.never)
                        }
                        Section {
                            SubmitButton(viewModel: viewModel)
                        }
                        .listRowBackground(Color(UIColor.systemGroupedBackground))
                    }
//                    .toolbar {
//                        ToolbarItem(placement: .keyboard) {
//                            Button("next") {
//                                if viewModel.firstName.isEmpty {
//                                    focus = .firstName
//                                } else if viewModel.lastName.isEmpty {
//                                    focus = .lastName
//                                }
//                                else if viewModel.email.isEmpty {
//                                    focus = .email
//                                }
//                                else if viewModel.newPassword.isEmpty {
//                                    focus = .newPassword
//                                }
//                                else if viewModel.confirmPassword.isEmpty {
//                                    focus = .confirmPassword
//                                }
//                                else if viewModel.accessKey.isEmpty {
//                                    focus = .accessKey
//                                } else {
//                                    focus = nil
//                                }
//                            }
//                        }
//                    }
                    .navigationTitle("Create an Account")
                    .alert(item: $viewModel.alertConfiguration, content: { info in
                        Alert(title: Text(info.title), message: Text(info.message), dismissButton: .default(Text(info.positiveActionTitle), action: {
                            switch info.id {
                            case .error, .informational:
                                return
                            case .success:
                                self.presentationMode.wrappedValue.dismiss()
                            }
                        }))
                    })
                }
                if (viewModel.isLoading) {
                    ProgressView()
                }
                
            }
        }
    }
    
    struct SubmitButton: View {
        @StateObject var viewModel: UserAccessKeyViewModel
        var body: some View {
            Button(action: {
                Task {
                    await viewModel.registerUser()
                }
            }) {
                Text("Submit")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .center)
                    .background(viewModel.allRequiredFieldsPresent() ? Color.green : Color.gray)
                    .disabled(!viewModel.allRequiredFieldsPresent())
                    .cornerRadius(15.0)
            }.padding(.top, UIScreen.main.bounds.height * 0.05)
                .buttonStyle(.plain)
            
        }
    }
    
    struct UserInformationView: View {
        @State var data: UserAccessKeyViewModel
        @FocusState var focus: FocusableField?
        var body: some View {
            Section("User Information") {
                TextField("First Name", text: $data.firstName)
//                    .focused($focus, equals: .firstName)
                TextField("Last Name", text: $data.lastName)
//                    .focused($focus, equals: .lastName)
                TextField("Email address", text: $data.email)
//                    .focused($focus, equals: .email)
                    .textInputAutocapitalization(.never)
                    .textContentType(.emailAddress)
            }
            Section("Password") {
                Text("""
    Your password must meet the following requirements:
    ⊝ Be between 6 and 64 characters.
    ⊝ Contain at least 1 number.
    ⊝ Contain at least 1 special character.
    """)
                .font(.caption)
                SecureField("Password", text: $data.newPassword)
                    .textInputAutocapitalization(.never)
                    .textContentType(.newPassword)
//                    .focused($focus, equals: .newPassword)
                SecureField("Confirm password", text: $data.confirmPassword)
                    .textInputAutocapitalization(.never)
                    .textContentType(.newPassword)
//                    .focused($focus, equals: .confirmPassword)
            }
        }
    }
    
    
}

struct UserAccessKeyView_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = UserAccessKeyViewModel(UserSession())
        UserAccessKeyView(viewModel: viewModel)
            .environmentObject(UserSession())
    }
}
