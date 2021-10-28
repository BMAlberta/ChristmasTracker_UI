//
//  LogMiddleware.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 1/17/21.
//

import Foundation
import Combine
import os

func logMiddleware() -> Middleware<AppState, AppAction> {

    return { state, action in
        os_log("Triggered action: \(action)")
        return Empty().eraseToAnyPublisher()
    }
}
