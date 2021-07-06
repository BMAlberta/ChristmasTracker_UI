//
//  LogMiddleware.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 1/17/21.
//

import Foundation
import Combine

func logMiddleware() -> Middleware<AppState, AppAction> {

    return { state, action in
        print("Triggered action: \(action)")
        return Empty().eraseToAnyPublisher()
    }
}
