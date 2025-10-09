//
//  AnalyticsMiddleware.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 10/3/25.
//

import Foundation

struct AnalyticsMiddleware<State>: Middleware {
    func process(action: any Action, state: State, dispatch: @escaping (any Action) -> Void) -> any Action {
        switch action {
        case let UserActions.login(username, password):
            trackEvent(action.type, parameters: ["username": username, "password": password])
            
        case UserActions.loginSuccess(let userToken):
            trackEvent(action.type, parameters: ["userToken": userToken])
        default:
            break
        }
        
        return action
    }
    
 
    
    private func trackEvent(_ eventName: String, parameters: [String: Any] = [:]) {
        print("📊 Analytics: \(eventName) - \(parameters)")
    }
    
}
