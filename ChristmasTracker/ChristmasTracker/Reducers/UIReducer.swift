//
//  UIReducer.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 10/1/25.
//

import Foundation

func uiReducer(state: UIState, action: any Action) -> UIState {
    var newState = state
    
    switch action {
    case let uiAction as UIActions:
        switch uiAction {
        case .setCurrentTab(let newTab):
            newState.currentTab = newTab
        case .showToast:
            fatalError("uiReducer: \(uiAction) not implemented")
        case .hideToast:
            fatalError("uiReducer: \(uiAction) not implemented")
        case .showUpdateDialog(let updateConfig):
            newState.updatePrompt = updateConfig
            newState.shouldPromptForUpdate = true
        case .hideUpdateDialog:
            newState.shouldPromptForUpdate = false
            newState.updatePrompt = nil
        case .showBiometricSheet:
            fatalError("uiReducer: \(uiAction) not implemented")
        case .hideBiometricSheet:
            fatalError("uiReducer: \(uiAction) not implemented")
        case .checkForUpdate:
            break
        case .updateCheckComplete(let updateModel):
            newState.shouldPromptForUpdate = Configuration.isUpdateAvailable(updateInfo: updateModel)
        }
    default:
        break
    }
    
    
    return newState
}

