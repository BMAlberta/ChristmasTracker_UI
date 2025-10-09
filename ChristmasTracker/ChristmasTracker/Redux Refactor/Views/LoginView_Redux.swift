//
//  LoginView_Redux.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 10/4/25.
//

import SwiftUI

struct LoginView_Redux: View {
    private var store: Store<AppState>
    @StateObject private var viewStore: ViewStore<LoginViewState>
    
    @State private var email = ""
    @State private var password = ""
    @State private var isRegistering = false
    
    
    init(store: Store<AppState>) {
        self.store = store
        self._viewStore = StateObject(wrappedValue: ViewStore(
            store: store,
            observe: { appState in
                LoginViewState(
                    isLoading: appState.user.isloading,
                    error: appState.user.error
                )
            }
        ))
    }
    
    
    var body: some View {
        ZStack {
            if (viewStore.state.isLoading) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Color.red) )
            } else if ((viewStore.state.error) != nil) {
                // TODO - Show error
                Text("Error state")
            } else {
                MainLoginView
            }
        }.onAppear {
            viewStore.dispatch(UIActions.checkForUpdate)
        }
    }
    
    private var MainLoginView: some View {
        VStack {
            TitleView
            LogoView
            CredentialsView
            Spacer()
        }
        .background(
            LinearGradient(gradient: Gradient(colors: [.brandBackgroundSecondary,
                                                       .brandBackgroundSecondary
            ]), startPoint: .top, endPoint: .bottom)
            .edgesIgnoringSafeArea(.all)
        )
    }
    
    private var CredentialsView: some View {
        VStack {
            VStack(alignment: .leading, spacing: 15) {
                TextField("Email", text: $email)
                    .padding()
                    .disableAutocorrection(true)
                    .autocapitalization(.none)
                    .textFieldStyle(PlaceholderStyle())
                    .background(Color.white)
                    .cornerRadius(20.0)
                    .shadow(radius: 10.0, x: 20, y: 10)
                
                HStack {
                    SecureField("Password", text: $password, onCommit: {
                        Task {
                            viewStore.dispatch(UserActions.login(email: email, password: password))
                        }                })
                        .padding()
                        .disableAutocorrection(true)
                        .autocapitalization(.none)
                        .textFieldStyle(PlaceholderStyle())

//                    if (self.viewModel.shouldShowBiometricOptions) {
//                        Button(action: {
//                            Task {
//                                await self.viewModel.handleBiometricInteraction()
//                            }
//                        }) {
//                            Image(systemName: "faceid")
//                                .resizable()
//                                .frame(width: 24, height: 24)
//                                .padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 16))
//                                .foregroundColor(.green)
//                        }
//                    }
                }
                .background(.white)
                .cornerRadius(20.0)
                .shadow(radius: 10.0, x:20, y: 10)
            }.padding([.leading, .trailing], 27.5)
            
            Button(action: {
                Task {
                    viewStore.dispatch(UserActions.login(email: email, password: password))
                }
            }) {
                Text("Sign In")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(width: 300, height: 50)
//                    .background(Color.green)
                    .background(.primaryGreen)
                    .cornerRadius(15.0)
                    .shadow(radius: 10.0, x: 20, y: 10)
            }.padding(.top, UIScreen.main.bounds.height * 0.05)
        }
    }
    
    private var EmailField: some View {
        TextField("Email", text: $email)
            .padding()
            .disableAutocorrection(true)
            .autocapitalization(.none)
            .textFieldStyle(PlaceholderStyle())
            .background(Color.white)
            .cornerRadius(20.0)
            .shadow(radius: 10.0, x: 20, y: 10)
    }
    
    private var PasswordField: some View {
        SecureField("Password", text: $password)
            .padding()
            .disableAutocorrection(true)
            .autocapitalization(.none)
            .background(Color.white)
            .textFieldStyle(PlaceholderStyle())
            .cornerRadius(20.0)
            .shadow(radius: 10.0, x: 20, y: 10)
    }
    
    private var LogoView: some View {
        Image("wreath")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: UIScreen.main.bounds.width * 0.75)
            .padding(.bottom, 20)
    }
    
    private var TitleView: some View {
        Text("Christmas Tracker")
            .font(.largeTitle).foregroundColor(Color.white)
            .padding([.top, .bottom], 20)
            .shadow(radius: 10.0, x: 20, y: 10)
    }
}

struct LoginViewState: Equatable {
    var isLoading: Bool
    var error: UserError?
}

#Preview {
    LoginView_Redux(store: StoreEnvironmentKey.defaultValue)
}
