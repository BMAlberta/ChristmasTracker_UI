//
//  AppAction.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 1/17/21.
//

import Foundation

enum AppAction {
    case auth(action: AuthAction)
    case list(action: ListAction)
}


extension AppAction: CustomStringConvertible {
    var description: String {
        switch self {
        case .auth(let action):
            return "authAction(\(action))"
        case .list(let action):
            return "listAction(\(action))"
                }
    }
}
