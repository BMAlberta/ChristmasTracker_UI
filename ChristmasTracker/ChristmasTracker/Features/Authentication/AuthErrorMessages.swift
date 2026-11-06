//
//  AuthErrorMessages.swift
//  ChristmasTracker
//
//  Created for Story C2.
//

import Foundation

nonisolated func userMessage(for error: AuthenticationError) -> String {
    switch error {
    case .invalidCredentials:
        return "The email or password is incorrect."
    case .accountDisabled:
        return "This account has been disabled. Contact your administrator."
    case .invalidRegistrationCode:
        return "The registration code is invalid."
    case .emailAlreadyExists:
        return "An account with this email address already exists."
    case .validation(let message):
        return message
    case .credentialExpired:
        return "Your session has expired. Please sign in again."
    case .invalidRefreshToken:
        return "Your session is no longer valid. Please sign in again."
    case .updateRequired:
        return "A required update is available. Please update the app."
    case .rateLimited:
        return "Too many attempts. Please wait a moment and try again."
    case .serverError:
        return "A server error occurred. Please try again later."
    case .networkError:
        return "A network error occurred. Please check your connection."
    case .invalidResponse:
        return "An unexpected error occurred. Please try again."
    case .userNotFound:
        return "An unexpected error occurred. Please try again."
    case .biometricFailed:
        return "An unexpected error occurred. Please try again."
    case .biometricNotAvailable:
        return "An unexpected error occurred. Please try again."
    case .sessionExpired:
        return "Your session has expired. Please sign in again."
    }
}
