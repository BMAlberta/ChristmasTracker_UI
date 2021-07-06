//
//  AppState.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 1/15/21.
//

import Foundation
import Combine


enum LoginState {
    case loggedIn
    case noAuth
    case authFailed
}


struct AppState_old {
    var authState: LoginState = .noAuth
    var isLoading: Bool = false
    var authToken = ""
    var userId = ""
}

enum Action {
    case appendNewItem(Item)
    case removeItem(Item)
    case markItemPurchased(Item)
    case editItem(Item)
    case set(state: AppState_old)
    case resetState
    case login(credentials: Credentials)
    case logout
}

final class AppStore_old: ObservableObject {
    @Published private(set) var state: AppState_old
    @Published var myListStore: MyListStore
    private(set) var sessionStore = UserSession()
    private var _effectCancellables: [UUID: AnyCancellable] = [:]
    private let _queue: DispatchQueue = .init(label: "com.alberta.christmastracker.store")
    
    init(initialState: AppState_old, session: UserSession ) {
        self.state = initialState
        self.myListStore = MyListStore(session: session)
    }
    
    
    func send(_ action: Action) {
        let effect = reduce(&state, action)

        var didComplete = false
        let uuid = UUID()

        let cancellable = effect
            .subscribe(on: DispatchQueue.main)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] _ in
                    didComplete = true
                    self?._effectCancellables[uuid] = nil
                },
                receiveValue: { [weak self] in
                    self?.send($0)
                    
                }
            )

        if !didComplete {
            _effectCancellables[uuid] = cancellable
        }
    }
}


extension AppStore_old {

    func reduce( _: inout AppState_old, _ action: Action) -> AnyPublisher<Action, Never> {
        
        switch (action) {
        
        case .appendNewItem(_):
            print("Append new item")
        case .removeItem(_):
            print("Remove item")
        case .markItemPurchased(_):
            print("Mark purchased")
        case .editItem(_):
            print("Edit item")
        case .set(state: let newState):
            print("Set the new state")
            self.state = newState
        case .resetState:
            print("Reset state")
        case .login(credentials: let credentials):
            print("Login")
            return sessionStore.performLogin(credentials)
                .replaceError(with: LoginResponse(token: "NO_TOKEN_FOUND"))
                .map { [self] in
                    self.state.authToken = $0.token
                    return .set(state: self.state)
                }
                .eraseToAnyPublisher()
        
        
            
        case .logout:
            print("Logout")
        }
        return Empty(completeImmediately: true).eraseToAnyPublisher()
    }
}
