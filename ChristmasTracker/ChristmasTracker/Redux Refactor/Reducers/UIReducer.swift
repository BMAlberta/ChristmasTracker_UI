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
        case .setCurrentTab(_):
            fatalError("uiReducer: \(uiAction) not implemented")
        case .showToast:
            fatalError("uiReducer: \(uiAction) not implemented")
        case .hideToast:
            fatalError("uiReducer: \(uiAction) not implemented")
        case .showUpdateDialog:
            fatalError("uiReducer: \(uiAction) not implemented")
        case .hideUpdateDialog:
            fatalError("uiReducer: \(uiAction) not implemented")
        case .showBiometricSheet:
            fatalError("uiReducer: \(uiAction) not implemented")
        case .hideBiometricSheet:
            fatalError("uiReducer: \(uiAction) not implemented")
        case .checkForUpdate:
//            break
            fatalError("uiReducer: \(uiAction) not implemented")
        case .updateCheckComplete(_):
            fatalError("uiReducer: \(uiAction) not implemented")
        }
    default:
        break
    }
    
    
    return newState
}

