//
//  NetworkAuthenticationRepository.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/8/26.
//

import Foundation

actor NetworkAuthenticationRepository: AuthenticationRepository {
    
    private let apiClient: APIClient
    
    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }
    
    
    func login(email: String, password: String, rememberMe: Bool) async throws -> AuthData {
        LogDebug("Login attempt: \(email)", category: .auth)
        
        let request = LoginRequest(email: email,
                                   password: password,
                                   rememberMe: rememberMe)
        
        do {
            let authResponse: AuthResponse = try await apiClient.request(.post,
                                                                         path: "/auth/login",
                                                                         body: request,
                                                                         forceRefresh: true,
                                                                         cacheScope: .none)
            
            LogInfo("Login successful: \(email)", category: .auth)
            return authResponse.data
            
            
        } catch let apiError as APIError {
            throw mapAPIError(apiError)
        }
    }
    
    func register(email: String, password: String, name: String) async throws -> AuthData {
        LogDebug("Register attempt: \(email)", category: .auth)
        
        let request = RegisterRequest(email: email,
                                      password: password,
                                      name: name,)
        
        do {
            let authResponse: AuthResponse = try await apiClient.request(.post,
                                                                         path: "/auth/register",
                                                                         body: request,
                                                                         forceRefresh: true,
                                                                         cacheScope: .none)
            LogInfo("Register successful: \(email)", category: .auth)
            return authResponse.data
            
        } catch let apiError as APIError {
            throw mapAPIError(apiError)
        }
    }
    
    func biometricLogin(userId: String, biometricToken: String) async throws -> AuthData {
        LogDebug("Biometric login attempt: \(userId)", category: .auth)
        
        let request = BiometricLoginRequest(userId: userId,
                                            biometricToken: biometricToken)
        
        do {
            let authResponse: AuthResponse = try await apiClient.request(.post,
                                                                         path: "/auth/biometric",
                                                                         body: request,
                                                                         forceRefresh: true,
                                                                         cacheScope: .none)
            LogInfo("Biometric login successful: \(userId)", category: .auth)
            return authResponse.data
        } catch let apiError as APIError {
            throw mapAPIError(apiError)
        }
    }
    
    func refreshToken(_ refreshToken: String) async throws -> AuthData {
        LogDebug("Token refresh attempt", category: .auth)
        
        let request = RefreshTokenRequest(refreshToken: refreshToken)
        
        do {
            let authResponse: AuthResponse = try await apiClient.request(.post,
                                                                         path: "/auth/refresh",
                                                                         body: request,
                                                                         forceRefresh: true,
                                                                         cacheScope: .none)
            LogInfo("Token refresh successful", category: .auth)
            return authResponse.data
        } catch let apiError as APIError {
            throw mapAPIError(apiError)
        }
    }
    
    func ping() async throws {
        LogDebug("Session ping", category: .auth)
        
        do {
            struct EmptyResponse: Codable {}
            let _ : EmptyResponse = try await apiClient.request(.post,
                                                                path: "/auth/ping",
                                                                body: .none,
                                                                forceRefresh: true,
                                                                cacheScope: .none)
            LogDebug("Session ping successful", category: .auth)
            
        } catch let apiError as APIError {
            throw mapAPIError(apiError)
        }
    }
    
    func logout(refreshToken: String) async throws {
        LogDebug("Logout attempt", category: .auth)
        
        struct LogoutRequest: Codable {
            let refreshToken: String
        }
        
        do {
            struct EmptyResponse: Codable {}
            let _ : EmptyResponse = try await apiClient.request(.post,
                                                                path: "/auth/logout",
                                                                body: .none,
                                                                forceRefresh: true,
                                                                cacheScope: .none)
            LogInfo("Logout success", category: .auth)
            
        } catch let apiError as APIError {
            throw mapAPIError(apiError)
        }
    }
    
    func forgotPassword(email: String) async throws {
        LogDebug("Forgot password: \(email)", category: .auth)
        
        let request = ForgotPasswordRequest(email: email)
        
        do {
            struct EmptyResponse: Codable {}
            let _ : EmptyResponse = try await apiClient.request(.post,
                                                                path: "/auth/forgot-password",
                                                                body: request,
                                                                forceRefresh: true,
                                                                cacheScope: .none)
            
            LogInfo("Password reset email sent", category: .auth)
        } catch let apiError as APIError {
            throw mapAPIError(apiError)
        }
    }
    
    // MARK: - Error Mapping
    private nonisolated func mapAPIError(_ error: APIError) -> AuthenticationError {
        switch error {
        case .httpError(let statusCode, let data):
            // Try to decode error response manually to avoid actor isolation issues
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorDict = json["error"] as? [String: Any],
               let errorCode = errorDict["errorCode"] as? String {
                return mapErrorCode(errorCode)
            }
            // Fallback based on status code
            switch statusCode {
            case 401:
                return .invalidCredentials
            case 409:
                return .emailAlreadyExists
            case 404:
                return .userNotFound
            default:
                return .networkError
            }
        case .networkUnavailable:
            return .networkError
        case .versionOutdated:
            return .networkError
        default:
            return .networkError
        }
        
    }
    private nonisolated func mapErrorCode(_ errorCode: String) -> AuthenticationError {
        switch errorCode {
        case "INVALID_CREDENTIALS":
            return .invalidCredentials
        case "EMAIL_ALREADY_EXISTS":
            return .emailAlreadyExists
        case "USER_NOT_FOUND":
            return .userNotFound
        case "INVALID_REFRESH_TOKEN", "SESSION_EXPIRED":
            return .sessionExpired
        default:
            return .networkError
        }
    }
}
