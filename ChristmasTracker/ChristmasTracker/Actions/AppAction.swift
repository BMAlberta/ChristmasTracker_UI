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
