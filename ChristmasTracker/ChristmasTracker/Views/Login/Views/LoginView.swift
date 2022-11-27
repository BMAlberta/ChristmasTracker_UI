//
//  LoginView.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 1/15/21.
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var _session: UserSession
    @StateObject var viewModel: LoginViewModel
    
    var body: some View {
        
        ZStack {
            if (viewModel.isLoading) {
                MainLoginView(viewModel: viewModel)
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Color.red))
            } else if (viewModel.isErrorState) {
                MainLoginView(viewModel: viewModel)
                    .alert(isPresented: $viewModel.isErrorState) {
                    Alert(title: Text(viewModel.alertCongfiguration.title),
                          message: Text(viewModel.alertCongfiguration.message),
                          dismissButton: .default(Text(viewModel.alertCongfiguration.positiveActionTitle)))
                }
            } else {
                MainLoginView(viewModel: viewModel)
                    .alert(isPresented: $viewModel.shouldPromptForUpdate) {
                        Alert(
                            title: Text(viewModel.updateConfiguration.title),
                            message: Text(viewModel.updateConfiguration.message),
                            primaryButton: .default(Text(viewModel.updateConfiguration.positiveActionTitle)) {
                                guard let updateUri = viewModel.updateConfiguration.updateUrl else {
                                    $viewModel.shouldPromptForUpdate.wrappedValue.toggle()
                                    return
                                }
                                $viewModel.shouldPromptForUpdate.wrappedValue.toggle()
                                UIApplication.shared.open(updateUri)
                                
                            },
                            secondaryButton: .cancel()
                        )
                    }
            }
        }
        .onAppear {
            Task {
                await self.viewModel.checkForUpdate()
            }
        }
    }
}



struct MainLoginView: View {
    @ObservedObject var viewModel: LoginViewModel
    @EnvironmentObject var _session: UserSession
    @State var showEnroll = false
    
    var body: some View {
        VStack() {
            TitleView()
            LogoView()
            CredentialsView(viewModel: viewModel)
            Spacer()
            EnrollView(showEnroll: $_session.enrollmentInProgress)
                .sheet(isPresented: $_session.enrollmentInProgress) {
                    UserAccessKeyView(viewModel: UserAccessKeyViewModel(_session))
                }
                .sheet(isPresented: $_session.passwordResetInProgress) {
                    PasswordResetView()
                }
            Spacer()
        }.background(
            LinearGradient(gradient: Gradient(colors: [Color("brandBackgroundPrimary"),
                                                       Color("brandBackgroundPrimary")
                                                      ]), startPoint: .top, endPoint: .bottom)
                .edgesIgnoringSafeArea(.all))
    }
}

struct PlaceholderStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .colorMultiply(.gray)
            .foregroundColor(.gray)
    }
}

extension Color {
    static var themeTextField: Color {
        return Color(red: 220.0/255.0, green: 230.0/255.0, blue: 230.0/255.0, opacity: 1.0)
    }
}


struct CredentialsView: View {
    @EnvironmentObject private var _session:UserSession
    @ObservedObject var viewModel: LoginViewModel
    
    var body: some View {
        VStack {
            VStack(alignment: .leading, spacing: 15) {
                TextField("Email", text: $viewModel.username)
                    .padding()
                    .disableAutocorrection(true)
                    .autocapitalization(.none)
                    .textFieldStyle(PlaceholderStyle())
                    .background(Color.white)
                    .cornerRadius(20.0)
                    .shadow(radius: 10.0, x: 20, y: 10)
                
                SecureField("Password", text: $viewModel.password, onCommit: {
                    Task {
                        await self.viewModel.doLogin()
                    }                })
                    .padding()
                    .disableAutocorrection(true)
                    .autocapitalization(.none)
                    .background(Color.white)
                    .textFieldStyle(PlaceholderStyle())
                    .cornerRadius(20.0)
                    .shadow(radius: 10.0, x: 20, y: 10)
            }.padding([.leading, .trailing], 27.5)
            
            Button(action: {
                Task {
                    await self.viewModel.doLogin()
                }
            }) {
                Text("Sign In")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(width: 300, height: 50)
                    .background(Color.green)
                    .cornerRadius(15.0)
                    .shadow(radius: 10.0, x: 20, y: 10)
            }.padding(.top, UIScreen.main.bounds.height * 0.05)
        }
    }
}

struct EmailField: View {
    @Binding var email: String
    var body: some View {
        TextField("Email", text: $email)
            .padding()
            .disableAutocorrection(true)
            .autocapitalization(.none)
            .textFieldStyle(PlaceholderStyle())
            .background(Color.white)
            .cornerRadius(20.0)
            .shadow(radius: 10.0, x: 20, y: 10)
    }
}

struct PasswordField: View {
    @Binding var password: String
    var body: some View {
        SecureField("Password", text: $password)
            .padding()
            .disableAutocorrection(true)
            .autocapitalization(.none)
            .background(Color.white)
            .textFieldStyle(PlaceholderStyle())
            .cornerRadius(20.0)
            .shadow(radius: 10.0, x: 20, y: 10)
    }
}

struct EnrollView: View {
    @Binding var showEnroll: Bool
    var body: some View {
        HStack(spacing: 0) {
            Text("Don't have an account? ")
                .foregroundColor(.white)
            Button(action: {
                showEnroll.toggle()
            }) {
                Text("Sign Up")
                    .foregroundColor(.white)
                    .underline()
            }
        }
    }
}

struct LogoView: View {
    var body: some View {
        Image("wreath")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: UIScreen.main.bounds.width * 0.75)
            .padding(.bottom, 20)
    }
}

struct TitleView: View {
    var body: some View {
        Text("Christmas Tracker")
            .font(.largeTitle).foregroundColor(Color.white)
            .padding([.top, .bottom], 20)
            .shadow(radius: 10.0, x: 20, y: 10)
    }
}


struct LoginView_Previews: PreviewProvider {
    
    static var session: UserSession {
        let session = UserSession()
        session.enrollmentInProgress = true
        return session
    }
    
    static var previews: some View {
        Group {
            let sampleViewModel = LoginViewModel(Self.session)
            LoginView(viewModel: sampleViewModel)
                .environmentObject(Self.session)
        }
    }
}
