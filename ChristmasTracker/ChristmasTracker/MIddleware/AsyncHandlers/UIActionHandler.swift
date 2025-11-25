//
//  UIActionHandler.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 10/10/25.
//

import Foundation

protocol UIActionHandling {
    func process(_ action: UIActions, dispatch: @escaping (any Action) -> Void)
}

struct UIActionHandler: UIActionHandling {
    let apiService: APIServiceProviding
    
    init(apiService: APIServiceProviding) {
        self.apiService = apiService
    }
    
    func process(_ action: UIActions, dispatch: @escaping (any Action) -> Void) {
        switch action {
        case .setCurrentTab(_):
            break
        case .showToast:
            fatalError("UIActionHandler: \(action) not implemented")
        case .hideToast:
            fatalError("UIActionHandler: \(action) not implemented")
        case .checkForUpdate:
            Task {
                do {
                    let updateResponse = try await apiService.updateAPI.fetchUpdateInfo()
                    await MainActor.run {
                        dispatch(UIActions.updateCheckComplete(updateResponse.version))
                    }
                } catch {
                    // TODO: Add update failure case?
                }
            }
        case .updateCheckComplete(let updateInfo):
            let isUpdateAvailable = Configuration.isUpdateAvailable(updateInfo: updateInfo)
            
            if isUpdateAvailable {
                let configuration = UpdateAlertConfiguration(title: "Update Available",
                                                             message: "An updated version of this application is available for download. For the optimal experience, please download the latest version before logging in.", positiveActionTitle: "Install Now",
                                                             updateUrl: Configuration.generateUpdateUri(updateInfo: updateInfo))
                dispatch(UIActions.showUpdateDialog(configuration))
            } else {
                dispatch(UIActions.hideUpdateDialog)
            }
            
        case .showUpdateDialog:
            break
        case .hideUpdateDialog:
            break
        case .showBiometricSheet:
            fatalError("UIActionHandler: \(action) not implemented")
        case .hideBiometricSheet:
            fatalError("UIActionHandler: \(action) not implemented")
        }
    }
}
