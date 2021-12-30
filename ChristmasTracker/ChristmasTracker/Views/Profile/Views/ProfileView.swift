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
    var body: some View {
        NavigationView {
            Form {
                Section("Profile Information") {
                    PersonView(data: viewModel.userModel)
                }
                Section("Historical Details") {
                    HistoryView(data: viewModel.userModel)
                }
                Section("Login Options") {
                    ChangePasswordButton(presented: $passwordChangePresented)
                    DisableSaveUserIdButton()
                }
                
                
                Section("Application Information") {
                    AppInfoView(data: self.viewModel.appInfo)
                }
            }
            .sheet(isPresented: $passwordChangePresented, onDismiss: nil, content: {
                ChangePasswordView(viewModel: ChangePasswordViewModel(_session))
            })
            .navigationBarTitle("Profile & Settings")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    LogoutButton(viewModel: self.viewModel)
                }
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
        var data: User?
        var body: some View {
            HStack {
                Text("Name:")
                Text("\(data?.firstName ?? "") \(data?.lastName ?? "")")
                    .font(.subheadline)
            }
            HStack {
                Text("Email:")
                Text(data?.email ?? "")
                    .font(.subheadline)
            }
            HStack {
                Text("Member Since:")
                Text(FormatUtility.convertDateStringToHumanReadable(rawDate: data?.creationDate))
                    .font(.subheadline)
            }
        }
    }
    
    private struct HistoryView: View {
        var data: User?
        var body: some View {
            HStack {
                Text("Last Login Date:")
                Text(FormatUtility.convertDateStringToHumanReadable(rawDate: data?.lastLogInDate))
                    .font(.subheadline)
            }
            HStack {
                Text("Last Login Location:")
                Text(data?.lastLogInLocation ?? "")
                    .font(.subheadline)
            }
            HStack {
                Text("Password Age (days):")
                Text("\(FormatUtility.calculateTimeInterval(from: data?.lastPasswordChange))")
                    .font(.subheadline)
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
            HStack {
                Spacer()
                Button("Change password") {
                    presented.toggle()
                }
                Spacer()
            }
        }
    }
    
    private struct DisableSaveUserIdButton: View {
        var body: some View {
            HStack {
                Spacer()
                Button(action: {
                    UserDefaults.standard.removeObject(forKey: "savedId")
                }) {
                    Text("Clear saved user ID")
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
                viewModel.logout()
                
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




