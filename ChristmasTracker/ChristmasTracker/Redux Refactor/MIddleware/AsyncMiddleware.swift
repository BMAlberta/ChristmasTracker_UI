//
//  AsyncMiddleware.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 10/3/25.
//

import Foundation

struct AsyncMiddleware<State>: Middleware {
    private let apiService: APIServiceProviding
    
    init(apiService: APIServiceProviding = APIService()) {
        self.apiService = apiService
    }
    
    
    func process(action: any Action, state: State, dispatch: @escaping (any Action) -> Void) -> any Action {
        
        if let userAction = action as? UserActions {
            handleUserActions(userAction, dispatch: dispatch)
        }
        
        if let uiAction = action as? UIActions {
            handleUIActions(uiAction, dispatch: dispatch)
        }
        
        return action
    }
    
    
    // MARK: - User Services
    
    private func handleUserActions(_ action: UserActions, dispatch: @escaping (any Action) -> Void) {
        switch action {
        case .login(email: let email, password: let password):
            Task {
                do {
                    let authResponse = try await apiService.userAPI.authenticateUser(Credentials(username: email, password: password))
                    await MainActor.run {
                        dispatch(UserActions.loginSuccess(authResponse.userInfo))
                        dispatch(ListActions.loadHomeFeed)
                    }
                } catch {
                    await MainActor.run {
                        dispatch(UserActions.loginError(error.localizedDescription))
                    }
                }
            }
            break
        case .biometricLogin:
            fatalError("AsyncMiddleware: handleUserActions: \(action) not implemented")
        case .loginSuccess(_):
            
            
            break
//            fatalError("AsyncMiddleware: handleUserActions: \(action) not implemented")
        case .loginError(_):
            fatalError("AsyncMiddleware: handleUserActions: \(action) not implemented")
        case .logout:
            fatalError("AsyncMiddleware: handleUserActions: \(action) not implemented")
        case .logoutSuccess:
            fatalError("AsyncMiddleware: handleUserActions: \(action) not implemented")
        case .refreshSession:
            fatalError("AsyncMiddleware: handleUserActions: \(action) not implemented")
        case .sessionExpired:
            fatalError("AsyncMiddleware: handleUserActions: \(action) not implemented")
        case .submitPasswordChange(currentPassword: let currentPassword, newPassword: let newPassword):
            fatalError("AsyncMiddleware: handleUserActions: \(action) not implemented")
        case .passwordChangeSuccess:
            fatalError("AsyncMiddleware: handleUserActions: \(action) not implemented")
        case .passwordChangeError(_):
            fatalError("AsyncMiddleware: handleUserActions: \(action) not implemented")
        case .enableBiometrics:
            fatalError("AsyncMiddleware: handleUserActions: \(action) not implemented")
        case .enableBiometricSuccess:
            fatalError("AsyncMiddleware: handleUserActions: \(action) not implemented")
        case .enableBiometricError(_):
            fatalError("AsyncMiddleware: handleUserActions: \(action) not implemented")
        case .resetLogonInfo:
            fatalError("AsyncMiddleware: handleUserActions: \(action) not implemented")
        case .resetSuccess:
            fatalError("AsyncMiddleware: handleUserActions: \(action) not implemented")
        }
    }
    
    // MARK: - UI Services
    
    private func handleUIActions(_ action: UIActions, dispatch: @escaping (any Action) -> Void) {
        switch action {
            
        case .setCurrentTab(_):
            fatalError("AsyncMiddleware: handleUIActions: \(action) not implemented")
        case .showToast:
            fatalError("AsyncMiddleware: handleUIActions: \(action) not implemented")
        case .hideToast:
            fatalError("AsyncMiddleware: handleUIActions: \(action) not implemented")
        case .checkForUpdate:
            Task {
                do {
                    
                    
                    
                } catch {
                    
                }
            }
            
            
            
            fatalError("AsyncMiddleware: handleUIActions: \(action) not implemented")
        case .updateCheckComplete(_):
            fatalError("AsyncMiddleware: handleUIActions: \(action) not implemented")
        case .showUpdateDialog:
            fatalError("AsyncMiddleware: handleUIActions: \(action) not implemented")
        case .hideUpdateDialog:
            fatalError("AsyncMiddleware: handleUIActions: \(action) not implemented")
        case .showBiometricSheet:
            fatalError("AsyncMiddleware: handleUIActions: \(action) not implemented")
        case .hideBiometricSheet:
            fatalError("AsyncMiddleware: handleUIActions: \(action) not implemented")
        }
    }
        
}

