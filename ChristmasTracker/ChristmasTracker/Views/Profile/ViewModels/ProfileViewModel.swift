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
    
    @Published var userModel: User?
    @Published var appInfo: ApplicationInfoModel = ApplicationInfoModel()
    @Published var isLoading = false
    @Published var isErrorState = false
    
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
            let userResponse: CurrentUserResponse = try await UserServiceStore.getCurrentUserDetails(token: _session.token)
            self.userModel = userResponse.user
            self.isLoading = false
            self.isErrorState = false
            
        } catch {
            self.isLoading = false
            self.isErrorState = true
        }
    }
    
    func logout() {
        _session.terminateSession()
    }
    
    func clearSavedUserId() {
        UserDefaults.standard.removeObject(forKey: "savedId")
    }
}

