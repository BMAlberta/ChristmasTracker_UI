//
//  LoginView.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 1/15/21.
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var store: AppStore
    
    var body: some View {
        
        let shouldDisplayError =  Binding<Bool>(
            get: { store.state.auth.isAuthError == true},
            set: { _ in () }
        )
        
        let shouldDisplayUpdateAlert =  Binding<Bool>(
            get: { Configuration.isUpdateAvailable(updateInfo: store.state.auth.updateInfo)},
            set: { _ in () }
        )
        
        ZStack {
            if (store.state.auth.authInProgress) {
                MainLoginView()
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Color.red))
            } else if (store.state.auth.isAuthError) {
                MainLoginView()
                    .alert(isPresented: shouldDisplayError) {
                        Alert(title: Text("Login Failed"), message: Text("The email and password combination you provided does not match our records. Please try again."), dismissButton: .default(Text("Ok")))
                    }
            } else {
                MainLoginView()
                    .alert(isPresented: shouldDisplayUpdateAlert) {
                        Alert(
                            title: Text("Update Available"),
                            message: Text("An updated version of this application is available for download. For the optimal experience, please download the latest version before logging in."),
                            primaryButton: .default(Text("Install Now")) {
                                guard let updateUri = Configuration.generateUpdateUri(updateInfo: store.state.auth.updateInfo) else {
                                    shouldDisplayUpdateAlert.wrappedValue.toggle()
                                    return
                                }
                                shouldDisplayUpdateAlert.wrappedValue.toggle()
                                UIApplication.shared.open(updateUri)
                                
                            },
                            secondaryButton: .cancel()
                        )
                    }
            }
        }
    }
}



struct MainLoginView: View {
    @State var email = UserDefaults.standard.string(forKey: "savedId") ?? ""
    @State var password = ""
    @State var showEnroll = false
    
    var body: some View {
        VStack() {
            TitleView()
            LogoView()
            CredentialsView(email: $email, password: $password)
            Spacer()
            EnrollView(showEnroll: $showEnroll)
                .alert(isPresented: $showEnroll) {
                    Alert(title: Text("Not Supported"), message: Text("Enrollment via the Mobile application is not currently supported. Please contact the developer for assistance."), dismissButton: .default(Text("Ok")))
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
    @EnvironmentObject private var _store: AppStore
    @Binding var email: String
    @Binding var password: String
    
    var body: some View {
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
                
                SecureField("Password", text: $password, onCommit: {
                    self.prepareLogin()
                })
                    .padding()
                    .disableAutocorrection(true)
                    .autocapitalization(.none)
                    .background(Color.white)
                    .textFieldStyle(PlaceholderStyle())
                    .cornerRadius(20.0)
                    .shadow(radius: 10.0, x: 20, y: 10)
            }.padding([.leading, .trailing], 27.5)
            
            Button(action: {
                self.prepareLogin()
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
    
    func prepareLogin() {
        let credentials = Credentials(username: email, password: password)
        _store.dispatch(.auth(action: .doLogin(credentials: credentials)))
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
    static let store = AppStore(initialState: .init(
        authState: AuthState(),
        listState: ListState()
    ),
                                reducer: appReducer,
                                middlewares: [
                                    authMiddleware(service: AuthService()),
                                    logMiddleware(),
                                    listMiddleware(service: ListService())
                                ])
    
    static var previews: some View {
        Group {
            LoginView().environmentObject(store)
        }
    }
}
