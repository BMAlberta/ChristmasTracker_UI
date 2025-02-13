//
//  ProfileView.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 1/18/21.
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var _session: UserSession
    @StateObject var viewModel: ProfileViewModel
    @State var passwordChangePresented = false
    @State var deleteProfilePresented = false
    @State var biometricSettingsPresented = false
    var body: some View {
        NavigationView {
            VStack {
                Form {
                    Section("Profile Information") {
                        PersonView(data: viewModel.userModel)
                    }
                    Section("Historical Details") {
                        HistoryView(data: viewModel.userModel)
                    }
                    Section("Login Options") {
                        ChangePasswordButton(presented: $passwordChangePresented)
                        BiometricLoginButton(presented: $biometricSettingsPresented)
                        DisableSaveUserIdButton()
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    
                    Section("Application Information") {
                        AppInfoView(data: self.viewModel.appInfo)
                        Button(action: {
                            Task {
                                await self.viewModel.checkForUpdate()
                            }
                        }) {
                            Text("Check for Update ")
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                    //TODO: Rebuild this functionality
//                    Section {
//                        DeleteUserProfileButton(presentDeleteFlow: $deleteProfilePresented)
//                    }
                }
                .sheet(isPresented: $passwordChangePresented, onDismiss: nil, content: {
                    ChangePasswordView(viewModel: ChangePasswordViewModel(_session))
                })
                .sheet(isPresented: $biometricSettingsPresented, onDismiss: nil, content: {
                    SignInOptionsView(viewModel: SignInOptionsViewModel(_session))
                })
                
                .navigationBarTitle("Profile & Settings")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        LogoutButton(viewModel: self.viewModel)
                    }
                }
                
                .alert(isPresented: $viewModel.shouldShowUpdateAlert) {
                    
                    
                    switch viewModel.alertInContext {
                    case .noUpdateFound:
                        return Alert(title: Text("No Update Found"),
                              message: Text("You are currently running the most recent available version of the application."),
                              dismissButton: .default(Text("Ok"),
                                                      action: {
                            viewModel.shouldShowUpdateAlert.toggle()
                        }))
                    case .updateFound:
                        return Alert(
                            title: Text(viewModel.updateConfiguration.title),
                            message: Text(viewModel.updateConfiguration.message),
                            primaryButton: .default(Text(viewModel.updateConfiguration.positiveActionTitle)) {
                                guard let updateUri = viewModel.updateConfiguration.updateUrl else {
                                    viewModel.shouldShowUpdateAlert.toggle()
                                    return
                                }
                                viewModel.shouldShowUpdateAlert.toggle()
                                UIApplication.shared.open(updateUri)
                                
                            },
                            secondaryButton: .cancel() {
                                viewModel.shouldShowUpdateAlert.toggle()
                            }
                        )
                    case .unknown:
                       return  Alert(title: Text("Error"),
                              message: Text("It looks like there was an error when checking for an update. Please try again later."),
                              dismissButton: .default(Text("Ok"),
                                                      action: {
                            viewModel.shouldShowUpdateAlert.toggle()
                        }))
                    }
                }
                NavigationLink(destination: DeleteProfileView(), isActive: $deleteProfilePresented) { EmptyView() }
            }
        }
        .navigationViewStyle(.stack)
        .onAppear {
            Task {
                await self.viewModel.fetchUserDetails()
            }
        }
    }
    
    private struct PersonView: View {
        var data: UserModel?
        var body: some View {
            HStack {
                Text("Name:")
                Text("\(data?.firstName ?? "") \(data?.lastName ?? "")")
                    .font(.subheadline)
                    .foregroundColor(Color.gray)
            }
            HStack {
                Text("Email:")
                Text(data?.email ?? "")
                    .font(.subheadline)
                    .foregroundColor(Color.gray)
            }
            HStack {
                Text("Member Since:")
                Text(FormatUtility.convertDateStringToHumanReadable(rawDate: data?.creationDate))
                    .font(.subheadline)
                    .foregroundColor(Color.gray)
            }
        }
    }
    
    private struct HistoryView: View {
        var data: UserModel?
        var body: some View {
            HStack {
                Text("Last Seen:")
                Text(FormatUtility.convertDateStringToHumanReadable(rawDate: data?.lastLogInDate))
                    .font(.subheadline)
                    .foregroundColor(Color.gray)
            }
            HStack {
                Text("Last Login Location:")
                Text(data?.lastLogInLocation ?? "")
                    .font(.subheadline)
                    .foregroundColor(Color.gray)
            }
            HStack {
                Text("Password Age (days):")
                Text("\(FormatUtility.calculateTimeInterval(from: data?.lastPasswordChange))")
                    .font(.subheadline)
                    .foregroundColor(Color.gray)
            }
        }
    }
    
    private struct AppInfoView: View {
        var data: ProfileViewModel.ApplicationInfoModel
        var body: some View {
            HStack {
                Text("Application Version:")
                Text(data.appVersion)
                    .font(.subheadline)
                    .foregroundColor(Color.gray)
            }
            HStack {
                Text("Build Date:")
                Text(data.buildDate)
                    .font(.subheadline)
                    .foregroundColor(Color.gray)
            }
        }
    }
    
    private struct ChangePasswordButton: View {
        @Binding var presented: Bool
        var body: some View {
            Button("Change password") {
                presented.toggle()
            }
        }
    }
    
    private struct BiometricLoginButton: View {
        @Binding var presented: Bool
        var body: some View {
            
            Button("Sign-In Options") {
                presented.toggle()
            }
        }
    }
    
    private struct DisableSaveUserIdButton: View {
        @State private var alertPresented = false
        var body: some View {
            
            Button(action: {
                alertPresented = true
            }) {
                Text("Clear saved user ID")
                    .foregroundColor(.red)
            }
            .alert(isPresented: $alertPresented) {
                Alert(
                    title: Text("Are you sure?"),
                    message: Text("This action will clear your saved user id from the system. You will have to re-enter your login credentials the next time you sign in.\n\nDo you wish to proceed?"),
                    primaryButton: .default(Text("Yes")) {
                        UserDefaults.standard.removeObject(forKey: "savedId")
                    },
                    secondaryButton: .cancel()
                )
            }
        }
    }
    private struct DeleteUserProfileButton: View {
        @Binding var presentDeleteFlow: Bool
        var body: some View {
            HStack {
                Spacer()
                Button(action: {
                    presentDeleteFlow.toggle()
                }) {
                    Text("Delete profile")
                        .foregroundColor(.red)
                }
                Spacer()
            }
        }
    }
    
    private struct LogoutButton: View {
        var viewModel: ProfileViewModel
        
        var body: some View {
            Button("Sign Out") {
                Task {
                    await viewModel.logout()
                }
            }
        }
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = ProfileViewModel(UserSession())
        ProfileView(viewModel: viewModel)
    }
}




