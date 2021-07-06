//
//  ListMiddleware.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 1/18/21.
//

import Foundation
import Combine

enum ListMiddlewareError: Error {
    case unknown
    case networkError
    case invalidURL
    case decoder
}

func listMiddleware(service: ListService) -> Middleware<AppState, AppAction> {
    
    return { state, action in
        
        switch action {
        case .list(action: .fetchData(let token)) :
            return service.getOwnedItems(token)
                .subscribe(on: DispatchQueue.main)
                .map { AppAction.list(action: .fetchComplete(res: $0)) }
                .catch { (error: ListServiceError) -> Just<AppAction> in
                    switch (error) {
                    case .networkError:
                        return Just(AppAction.list(action: .fetchError(error: .networkError)))
                    case .unknown:
                        return Just(AppAction.list(action: .fetchError(error: .unknown)))
                    case .invalidURL:
                        return Just(AppAction.list(action: .fetchError(error: .invalidURL)))
                    case .decoder(_):
                        return Just(AppAction.list(action: .fetchError(error: .decoder)))
                    case .url(_):
                        return Just(AppAction.list(action: .fetchError(error: .unknown)))
                    }
                }
                .eraseToAnyPublisher()
            
        case .list(action: .createItem(let newItem)):
            return service.addNewItem(token: state.auth.token, newItem: newItem)
                .subscribe(on: DispatchQueue.main)
                .map { AppAction.list(action: .createComplete(newItem: $0)) }
                .catch { (error: ListServiceError) -> Just<AppAction> in
                    switch (error) {
                    case .networkError:
                        return Just(AppAction.list(action: .fetchError(error: .networkError)))
                    case .unknown:
                        return Just(AppAction.list(action: .fetchError(error: .unknown)))
                    case .invalidURL:
                        return Just(AppAction.list(action: .fetchError(error: .invalidURL)))
                    case .decoder(_):
                        return Just(AppAction.list(action: .fetchError(error: .decoder)))
                    case .url(_):
                        return Just(AppAction.list(action: .fetchError(error: .unknown)))
                    }
                }
                .eraseToAnyPublisher()
        case .list(action: .createComplete(_)):
            return Just(AppAction.list(action: .fetchData(token: state.auth.token)))
                .eraseToAnyPublisher()
        default:
            break
        }
        return Empty().eraseToAnyPublisher()
    }
}


