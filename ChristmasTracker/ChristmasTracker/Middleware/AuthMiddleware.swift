//
//  AuthMiddleware.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 1/17/21.
//

import Foundation
import Combine

enum AuthMiddlewareError: Error {
    case unknown
    case networkError
    case invalidURL
    case decoder
}

func authMiddleware(service: AuthService) -> Middleware<AppState, AppAction> {
    
    return { state, action in
        switch action {
            
        case .auth(action: .doLogin(let credentials)):
            
            return service.performLogin(credentials)
                .subscribe(on: DispatchQueue.main)
                .map { AppAction.auth(action: .loginComplete(res: $0)) }
                .catch { (error: AuthServiceError) -> Just<AppAction> in
                    switch (error) {
                    case .networkError:
                        return Just(AppAction.auth(action: .loginError(error: .networkError)))
                    case .unknown:
                        return Just(AppAction.auth(action: .loginError(error: .unknown)))
                    case .invalidURL:
                        return Just(AppAction.auth(action: .loginError(error: .invalidURL)))
                    case .decoder(_):
                        return Just(AppAction.auth(action: .loginError(error: .decoder)))
                    case .url(_):
                        return Just(AppAction.auth(action: .loginError(error: .unknown)))
                    }
                }
                .eraseToAnyPublisher()
            
            default:
                break
            }
        
        return Empty().eraseToAnyPublisher()
    }
}


