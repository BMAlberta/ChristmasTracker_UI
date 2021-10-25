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
        case .list(action: .fetchOwnedList(let token)) :
            return service.getOwnedItems(token)
                .subscribe(on: DispatchQueue.main)
                .map { AppAction.list(action: .fetchOwnedListComplete(res: $0)) }
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
            
        case .list(action: .fetchListOverview(let token)) :
            return service.getListOverviewByUser(token)
                .subscribe(on: DispatchQueue.main)
                .map { AppAction.list(action: .fetchListOverviewComplete(res: $0)) }
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
            
        case .list(action: .fetchUserList(let token, let userId)) :
            return service.getListForUser(token, userId: userId)
                .subscribe(on: DispatchQueue.main)
                .map { AppAction.list(action: .fetchUserListComplete(res: $0)) }
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
            return Just(AppAction.list(action: .fetchOwnedList(token: state.auth.token)))
                .eraseToAnyPublisher()
            
        case .list(action: .purchaseItem(item: let item)):
            return service.markItemPurchased(token: state.auth.token, item: item)
                .subscribe(on: DispatchQueue.main)
                .map { _ in AppAction.list(action: .purchaseComplete) }
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
            
        case .list(action: .purchaseComplete):
            return Just(AppAction.list(action: .fetchUserList(token: state.auth.token, userId: state.ownedList.userIdContext)))
                .eraseToAnyPublisher()
            
        case .list(action: .retractPurchase(item: let item)):
            return service.markItemRetracted(token: state.auth.token, item: item)
                .subscribe(on: DispatchQueue.main)
                .map { _ in AppAction.list(action: .purchaseComplete) }
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
            
        case .list(action: .retractComplete):
            return Just(AppAction.list(action: .fetchUserList(token: state.auth.token, userId: state.ownedList.userIdContext)))
                .eraseToAnyPublisher()
            
        case .list(action: .updateItem(let token, let item)):
            return service.updateItem(token: token, item: item)
                .subscribe(on: DispatchQueue.main)
                .map { _ in AppAction.list(action: .updateComplete) }
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
        case .list(action: .updateComplete):
            return Just(AppAction.list(action: .fetchUserList(token: state.auth.token, userId: state.ownedList.userIdContext)))
                .eraseToAnyPublisher()
            
        case .list(action: .deleteItem(let token, let item)):
            return service.deleteItem(token: token, item: item)
                .subscribe(on: DispatchQueue.main)
                .map { _ in AppAction.list(action: .deleteComplete) }
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
            
        case .list(action: .deleteComplete):
            return Just(AppAction.list(action: .fetchOwnedList(token: state.auth.token)))
                .eraseToAnyPublisher()
            
        default:
            break
        }
        return Empty().eraseToAnyPublisher()
    }
}


