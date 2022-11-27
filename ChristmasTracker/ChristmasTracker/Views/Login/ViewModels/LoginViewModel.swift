//
//  LoginViewModel.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 12/14/21.
//

import Foundation
import Combine


struct AlertConfiguration: CustomDebugStringConvertible, Identifiable {
    
    enum AlertType {
        case error
        case success
        case informational
    }
    
    var id: AlertType = .error
    var title: String = ""
    var message: String = ""
    var positiveActionTitle: String = ""
    
    var debugDescription: String {
        """
        
            title: \(title)
            message: \(message)
            positiveActionTitle: \(positiveActionTitle)
        """
    }
}

class LoginViewModel: ObservableObject {
    struct UpdateAlertConfiguration: CustomDebugStringConvertible {
        var title: String = ""
        var message: String = ""
        var positiveActionTitle: String = ""
        var updateUrl: URL? = nil
        
        var debugDescription: String {
            """

                title: \(title)
                message: \(message)
                positiveActionTitle: \(positiveActionTitle)
                updateUrl: \(String(describing: updateUrl))
            """
        }
    }
    
    @Published var alertCongfiguration = AlertConfiguration()
    @Published var updateConfiguration = UpdateAlertConfiguration()
    @Published var shouldPromptForUpdate = false
    @Published var isLoading = false
    @Published var isErrorState = false
    @Published var username = UserDefaults.standard.string(forKey: "savedId") ?? ""
    @Published var password = ""
    
    private var _session: UserSession
    
    init(_ session: UserSession) {
        _session = session
    }
    
    @MainActor
    func doLogin() async {
        self.isLoading = true
        let suppliedCredentials = Credentials(username: self.username,
                                              password: self.password)
        do {
            let loginResponse: LoginResponse = try await AuthServiceStore.performLogin(suppliedCredentials)
            let currentUserResponse: CurrentUserResponse = try await UserServiceStore.getUserDetails(forId: loginResponse.userInfo)
            self._session.startSession(activeUser: currentUserResponse.user)
            self.isLoading = false
            self.isErrorState = false
            
        } catch let error as AuthServiceError {
            self.alertCongfiguration = self.generateAlertConfiguration(authError: error)
            self.isLoading = false
            self.isErrorState = true
        }
        catch is UserServiceError {
            // TODO: Need to call logout from here
            let alertConfiguration = AlertConfiguration(title: "Temporarily Unavailable",
                                                        message: "We're temporarily unable to connect. Thank you for your patience. Please try again later.",
                                                        positiveActionTitle: "OK")
            self.alertCongfiguration = alertConfiguration
            self.isLoading = false
            self.isErrorState = true
        }
        
        catch {
            let convertedError = error as? AuthServiceError ?? .unknown
            self.alertCongfiguration = self.generateAlertConfiguration(authError: convertedError)
            self.isLoading = false
            self.isErrorState = true
        }
        
    }
    
    @MainActor
    func checkForUpdate() async {
        self.shouldPromptForUpdate = false
        do {
            let updateResponse: UpdateInfoModelResponse = try await UpdateServiceStore.fetchUpdateInfo()
            let configuration = UpdateAlertConfiguration(title: "Update Available",
                                                         message: "An updated version of this application is available for download. For the optimal experience, please download the latest version before logging in.", positiveActionTitle: "Install Now",
                                                         updateUrl: Configuration.generateUpdateUri(updateInfo: updateResponse.version))
            self.updateConfiguration = configuration
            self.shouldPromptForUpdate = Configuration.isUpdateAvailable(updateInfo: updateResponse.version)
        } catch {
            self.shouldPromptForUpdate = false
        }
    }

    private func generateAlertConfiguration(authError: AuthServiceError) -> AlertConfiguration {
        
        var localAlertConfiguration = AlertConfiguration()
        switch authError {
        case .networkError, .unknown, .invalidURL, .url(_):
            localAlertConfiguration.title = "Temporarily Unavailable"
            localAlertConfiguration.message = "We're temporarily unable to connect. Thank you for your patience and please try again later."
            localAlertConfiguration.positiveActionTitle = "OK"
        case .decoder(_):
            localAlertConfiguration.title = "Login Failed"
            localAlertConfiguration.message = "The email and password combination you provided does not match our records. Please try again."
            localAlertConfiguration.positiveActionTitle = "OK"
        }
        return localAlertConfiguration
    }
}

extension LoginViewModel: CustomDebugStringConvertible {
    var debugDescription: String {
        """
        isLoading: \(isLoading)
        isErrorState: \(isErrorState)
        shouldPromptForUpdate: \(shouldPromptForUpdate)
        username: \(username)
        password: \(password)
        alertConfiguration: \(alertCongfiguration)
        updateConfiguration: \(updateConfiguration)
        """
    }
}
