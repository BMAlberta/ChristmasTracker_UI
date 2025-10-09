//
//  UIActions.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 10/1/25.
//

enum UIActions: Action {
    case setCurrentTab(AppTab)
    case showToast
    case hideToast
    case checkForUpdate
    case updateCheckComplete(UpdateInfoModel)
    case showUpdateDialog
    case hideUpdateDialog
    case showBiometricSheet
    case hideBiometricSheet
    
    
    var type: String {
        switch self {
        case .setCurrentTab: return "UI_SET_CURRENT_TAB"
        case .showToast: return "UI_SHOW_TOAST"
        case .hideToast: return "UI_HIDE_TOAST"
        case .showUpdateDialog: return "UI_SHOW_UPDATE_DIALOG"
        case .hideUpdateDialog: return "UI_HIDE_UPDATE_DIALOG"
        case .showBiometricSheet: return "UI_SHOW_BIOMETRIC_SHEET"
        case .hideBiometricSheet: return "UI_HIDE_BIOMETRIC_SHEET"
        case .checkForUpdate: return "UI_CHECK_FOR_UPDATE"
        case .updateCheckComplete(_): return "UI_UPDATE_CHECK_COMPLETE"
        }
    }
}
