//
//  ProfileViewModel.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 12/5/21.
//

import Foundation
import Combine

class ProfileViewModel: ObservableObject {
    
    struct ApplicationInfoModel {
        var appVersion: String = ""
        var buildDate: String = ""
    }
    
    enum AlertVariation {
        case noUpdateFound
        case updateFound
        case unknown
    }
    
    @Published var userModel: UserModel?
    @Published var updateConfiguration = UpdateAlertConfiguration()
    @Published var appInfo: ApplicationInfoModel = ApplicationInfoModel()
    @Published var isLoading = false
    @Published var isErrorState = false
    @Published var shouldShowUpdateAlert = false
    @Published var alertInContext: AlertVariation = .noUpdateFound
    
    private var _session: SessionManaging
    
    init(_ session: SessionManaging) {
        _session = session
        self.userModel = _session.loggedInUser
        appInfo = self.createAppInfoModel()
    }
    
    private func createAppInfoModel() -> ApplicationInfoModel {
        return ApplicationInfoModel(appVersion: Configuration.appVersion,
                                    buildDate: Configuration.buildDate)
    }
    
    
    
    
    @MainActor
    func fetchUserDetails() async {
        
        guard self.userModel == nil else {
            return
        }
        
        self.isLoading = true
        do {
            let userResponse: CurrentUserResponse = try await UserServiceStore.getUserDetails(forId: "")
            self.userModel = userResponse.user
            self.isLoading = false
            self.isErrorState = false
            
        } catch {
            self.isLoading = false
            self.isErrorState = true
        }
    }
    
    @MainActor
    func logout() async {
        
        self.isLoading = true
        let _ = await AuthServiceStore.performLogout()
        self.isLoading = false
        self.isErrorState = false
        _session.terminateSession()
    }
    
    func clearSavedUserId() {
        UserDefaults.standard.removeObject(forKey: "savedId")
    }
    
    @MainActor
    func checkForUpdate() async {
        self.shouldShowUpdateAlert = false
        do {
            let updateResponse: UpdateInfoModelResponse = try await UpdateServiceStore.fetchUpdateInfo()
            let configuration = UpdateAlertConfiguration(title: "Update Available",
                                                         message: "An updated version of this application is available for download. For the optimal experience, please download the latest version before logging in.", positiveActionTitle: "Install Now",
                                                         updateUrl: Configuration.generateUpdateUri(updateInfo: updateResponse.version))
            self.updateConfiguration = configuration
            let isUpdateAvailable = Configuration.isUpdateAvailable(updateInfo: updateResponse.version)
            
            self.alertInContext = isUpdateAvailable ? .updateFound : .noUpdateFound
            self.shouldShowUpdateAlert = true
        } catch {
            self.alertInContext = .unknown
            self.shouldShowUpdateAlert = true
        }
    }
}

