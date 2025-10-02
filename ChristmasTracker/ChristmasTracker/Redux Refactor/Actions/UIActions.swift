//
//  UIActions.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 10/1/25.
//

enum UIActions: Action {
    case setCurrentTab(String)
    case showLoginSheet
    case hideLoginSheet
//    case showCartSheet
//    case hideCartSheet
    case showToast(String)
    case hideToast
    case setNetworkStatus(Bool)
    
    var type: String {
        switch self {
        case .setCurrentTab: return "UI_SET_CURRENT_TAB"
        case .showLoginSheet: return "UI_SHOW_LOGIN_SHEET"
        case .hideLoginSheet: return "UI_HIDE_LOGIN_SHEET"
//        case .showCartSheet: return "UI_SHOW_CART_SHEET"
//        case .hideCartSheet: return "UI_HIDE_CART_SHEET"
        case .showToast: return "UI_SHOW_TOAST"
        case .hideToast: return "UI_HIDE_TOAST"
        case .setNetworkStatus: return "UI_SET_NETWORK_STATUS"
        }
    }
}

