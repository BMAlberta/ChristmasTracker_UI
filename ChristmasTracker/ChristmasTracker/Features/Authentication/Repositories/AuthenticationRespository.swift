//
//  AuthenicationRespository.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/8/26.
//

import Foundation

/// Protocol for authentication access.
protocol AuthenticationRepository: Sendable {
    
    /// Traditional login request.
    /// - Parameters:
    ///   - email: String represented the user's registered email address.
    ///   - password: String containing the uesr's entered password.
    ///   - rememberMe: Boolean indicator if the user chooses to has their username saved.
    /// - Returns: AuthData containing the authentication details.
    func login(email: String, password: String, rememberMe: Bool) async throws -> AuthData
    
    /// New user registration request.
    /// - Parameters:
    ///   - email: String representing the desired email address.
    ///   - password: String containing the user's entered password.
    ///   - name: String representing the user's name.
    /// - Returns: AuthData containing the authentication details.
    func register(email: String, password: String, name: String) async throws -> AuthData
    
    /// Biometric Login Request
    /// - Parameters:
    ///   - userId: String representing the user id.
    ///   - biometricToken: String containing the refresh token from the keychain.
    /// - Returns: AuthData containing the authentication details.
    func biometricLogin(userId: String, biometricToken: String) async throws -> AuthData
    
    /// Request to obtain a refresh token.
    /// - Parameters:
    ///   - refreshToken: Existing refresh token.
    /// - Returns: AuthData containing the authentication details.
    func refreshToken(_ refreshToken: String) async throws -> AuthData
    
    /// Keep-alive request.
    func ping() async throws
    
    /// Logout request.
    /// - Parameter refreshToken: String containing the current refresh token.
    func logout(refreshToken: String) async throws
    
    /// Forgot password request.
    /// - Parameter email: String containing the email address of the user.
    func forgotPassword(email: String) async throws
}
