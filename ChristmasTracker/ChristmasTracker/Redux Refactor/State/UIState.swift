//
//  UIState.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 10/1/25.
//

import Foundation
struct UIState: Equatable {
    var isNetworkConnected: Bool
    var currentTab: AppTab
    var showingLoginSheet: Bool
    var toast: ToastMessage?
    
    static let initialState = UIState(
        isNetworkConnected: true,
        currentTab: .home,
        showingLoginSheet: false,
        toast: nil
    )
}

enum AppTab: String, CaseIterable {
    case home = "Home"
    case lists = "Lists"
    case stats = "Stats"
    case profile = "Profile"
    
    var iconName: String {
        switch self {
        case .home: return "list.bullet"
        case .lists: return "cart"
        case .stats: return "cart"
        case .profile: return "person"
        }
    }
}

struct ToastMessage: Equatable {
    let message: String
    let type: ToastType
    let duration: TimeInterval
    
    enum ToastType {
        case success
        case error
        case info
    }
}
