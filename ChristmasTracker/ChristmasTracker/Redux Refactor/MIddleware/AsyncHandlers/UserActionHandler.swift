//
//  UserHandler.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 10/10/25.
//

import Foundation

protocol UserActionHandling {
    func process(_ action: UserActions, dispatch: @escaping (any Action) -> Void)
}

struct UserActionHandler: UserActionHandling {
    private let apiService: APIServiceProviding
    
    init(apiService: APIServiceProviding) {
        self.apiService = apiService
    }
    
    
    func process(_ action: UserActions, dispatch: @escaping (any Action) -> Void) {
        switch action {
        case .login(email: let email, password: let password, enableBiometrics: let enableBiometrics):
            Task {
                do {
                    let authResponse = try await apiService.userAPI.authenticateUser(Credentials(username: email, password: password))
                    await MainActor.run {
                        dispatch(UserActions.loginSuccess(authResponse.userInfo))
                        dispatch(ListActions.loadHomeFeed)
                        if (enableBiometrics) {
                            dispatch(UserActions.enableBiometrics(confirmedPassword: password))
                        }
                    }
                } catch let error as UserError {
                    await MainActor.run {
                        dispatch(UserActions.loginError(error))
                    }
                } catch {
                    await MainActor.run {
                        dispatch(UserActions.loginError(.authenticationFailed))
                    }
                }
                
            }
            break
        case .biometricLogin:
            Task {
                do {
                    let storedCredentials = try BiometricUtility.getStoredCredentials()
                    let authResponse = try await apiService.userAPI.authenticateUser(storedCredentials)
                    await MainActor.run {
                        dispatch(UserActions.loginSuccess(authResponse.userInfo))
                    }
                    
                } catch {
                    await MainActor.run {
                        dispatch(UserActions.loginError(error as! UserError))
                    }
                }
            }
            
            
            
            
            
        case .loginSuccess(_):
            break
        case .loginError(_):
            break
        case .logout:
            Task {
                let _ = try await apiService.userAPI.performLogout()
                dispatch(UserActions.logoutSuccess)
            }
        case .logoutSuccess:
            dispatch(UIActions.setCurrentTab(.home))
        case .loginErrorsCleared:
            break
        case .submitPasswordChange(currentPassword: let currentPassword, newPassword: let newPassword):
            Task {
                do {
                    let _ = try await apiService.userAPI.updatePassword(oldPassword: currentPassword, newPassword: newPassword)
                    await MainActor.run {
                        dispatch(UserActions.passwordChangeSuccess)
                    }
                } catch {
                    await MainActor.run {
                        dispatch(UserActions.passwordChangeError(error as! UserError))
                    }
                }
            }
        case .passwordChangeSuccess:
            dispatch(UserActions.refreshMetadata)
        case .passwordChangeError(_):
            break
        case .passwordChangeFlowComplete:
            break
        case .updateProfileName(userId: let userId, firstName: let firstName, lastName: let lastName):
            Task {
                do {
                    let _ = try await apiService.userAPI.updateProfileName(userId: userId, firstName: firstName, lastName: lastName)
                    await MainActor.run {
                        dispatch(UserActions.updateProfileNameSuccess)
                    }
                } catch {
                    await MainActor.run {
                        dispatch(UserActions.updateProfileNameError(error as! UserError))
                    }
                }
            }
            
        case .updateProfileNameSuccess:
            Task {
                await MainActor.run {
                    dispatch(UserActions.refreshMetadata)
                }
            }
            
        case .updateProfileNameError(let error):
            break
        case .updateProfileFlowComplete:
            break
        case .checkForBiometrics:
            Task {
                let state = BiometricUtility.biometricStatus
                await MainActor.run {
                    dispatch(UserActions.checkforBiometricsSuccess(state))
                }
            }
            
        case .checkforBiometricsSuccess(_):
            break
        case .enableBiometrics(let password):
            Task {
                guard let savedUsername = UserDefaults.standard.string(forKey: "savedId") else {
                    await MainActor.run {
                        dispatch(UserActions.enableBiometricError(.invalidCredentials))
                    }
                    return
                }
                let credentials = Credentials(username: savedUsername, password: password)
                do {
                    try BiometricUtility.handleBiometricEnrollment(credentials)
                    await MainActor.run {
                        dispatch(UserActions.enableBiometricSuccess)
                    }
                } catch {
                    await MainActor.run {
                        dispatch(UserActions.enableBiometricError(.invalidCredentials))
                    }
                }
            }
            
        case .enableBiometricSuccess:
            break
            
        case .enableBiometricError(_):
            break
            
        case .disableBiometrics:
            Task {
                do {
                    let _ = try BiometricUtility.deleteStoredCredentials()
                    await MainActor.run {
                        dispatch(UserActions.disableBiometricsSuccess)
                    }
                } catch {
                    await MainActor.run {
                        dispatch(UserActions.disableBiometricsError(error as! UserError))
                    }
                }
            }
        case .disableBiometricsSuccess:
            break
            
        case .disableBiometricsError(_):
            break
            
        case .homeFeedLoaded(_):
            break
        case .refreshMetadata:
            Task {
                do {
                    let metadataResponse = try await apiService.userAPI.fetchUserMetadata()
                    let metadata = metadataResponse.userMetadata
                    await MainActor.run {
                        dispatch(UserActions.metadataRefreshed(metadata))
                    }
                } catch {
                    await MainActor.run {
                        dispatch(UserActions.refreshMetadataError(error as! UserError))
                    }
                }
            }
        case .metadataRefreshed:
            break
        case .refreshMetadataError(let error):
            fatalError("UserActionHandler: \(action) not implemented")
        }
    }
    
}
