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
    var toast: ToastMessage?
    var shouldPromptForUpdate: Bool
    var updatePrompt: UpdateAlertConfiguration?
    
    static let initialState = UIState(
        isNetworkConnected: true,
        currentTab: .home,
        toast: nil,
        shouldPromptForUpdate: false,
        updatePrompt: nil
    )
}

enum AppTab: String, CaseIterable {
    case home = "Home"
    case stats = "Stats"
    case profile = "Profile"
    
    var iconName: String {
        switch self {
        case .home: return "house.fill"
//        case .lists: return "list.bullet"
        case .stats: return "chart.xyaxis.line"
        case .profile: return "person.crop.circle"
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


struct UpdateAlertConfiguration: Equatable, CustomDebugStringConvertible {
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
