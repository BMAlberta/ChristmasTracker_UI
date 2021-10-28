//
//  ProfileView.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 1/18/21.
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var _store: AppStore
    @State var passwordChangePresented = false
    var body: some View {
        NavigationView {
            Form {
                Section("Profile Information") {
                    PersonView(data: _store.state.auth.currentUserDetails)
                }
                Section("Historical Details") {
                    HistoryView(data: _store.state.auth.currentUserDetails)
                }
                ChangePasswordButton(presented: $passwordChangePresented)
                
                Section("Application Information") {
                    AppInfoView()
                }
            }
            .sheet(isPresented: $passwordChangePresented, onDismiss: nil, content: {
                ChangePasswordView()
            })
            .navigationBarTitle("Profile & Settings")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    LogoutButton()
                }
            }
        }
        .navigationViewStyle(.stack)
        .onAppear {
            if _store.state.auth.currentUserDetails == nil {
                let token = _store.state.auth.token
                _store.dispatch(.auth(action: .fetchCurrenUser(token: token)))
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
        var body: some View {
            HStack {
                Text("Application Version:")
                Text(Configuration.appVersion)
                    .font(.subheadline)
                    .foregroundColor(Color.gray)
            }
            HStack {
                Text("Build Date:")
                Text(Configuration.buildDate)
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
    
    private struct LogoutButton: View {
        @EnvironmentObject var store: AppStore
        
        var body: some View {
            Button("Sign Out") {
                store.dispatch(.auth(action: .logout))
                
            }
        }
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        
        let store = AppStore(initialState: .init(
            authState: AuthState(),
            listState: ListState()
        ),
                             reducer: appReducer,
                             middlewares: [
                                authMiddleware(service: AuthService()),
                                logMiddleware(),
                                listMiddleware(service: ListService())
                             ])
        ProfileView().environmentObject(store)
    }
}




