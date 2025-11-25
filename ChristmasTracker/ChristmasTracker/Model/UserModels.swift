//
//  UserModels.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 11/15/25.
//

import Foundation


// MARK: - Authentication Models
struct AuthResponse: Codable, Equatable {
    let userInfo: AuthModel
}

struct AuthModel: Codable, Equatable {
    let userId: String
    let firstName: String
    let lastName: String
    let pcr: Bool
}

struct Credentials: Codable {
    
    /// User's username.
    let username: String
    
    /// User's password.
    let password: String
}


// MARK: - Enrollment Models
struct AccessKeyEnrollmentModel: Codable {
    let firstName: String
    let lastName: String
    let email: String
    let newPassword: String
    let confirmPassword: String
    let accessKey: String
}

enum AccessKeyEnrollmentError: String, Codable {
    case inputValidation = "100.5.1"
    case passwordValidation = "100.5.2"
    case emailRegistered = "100.5.3"
    case invalidAccessKey = "100.5.4"
    case userCreationFailed = "100.5.5"
    case unknown
    case none
    
    var errorMessage: String {
        switch self {
        case .inputValidation:
            return "The information you added contains one or more errors. Please check your entries and try again."
        case .passwordValidation:
            return "The password provided does not meet the complexity requirements."
        case .emailRegistered:
            return "The email address provided is already registered to another user."
        case .invalidAccessKey:
            return "The access key your provided is not valid or has expired."
        case .userCreationFailed, .unknown:
            return "We're temporarily unable to connect. Thank you for your patience. Please try again later."
        case .none:
            return ""
        }
    }
}

// MARK: - Metadata Models
struct LWUserModel: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let firstName: String
    let lastName: String
    
    enum CodingKeys: String, CodingKey {
        case id = "userId"
        case firstName
        case lastName
    }
}

struct UserMetadataResponse: Codable, Equatable {
    let userMetadata: UserMetadata
}

struct UserMetadata: Codable, Equatable {
    let userId: String
    let email: String
    let firstName: String
    let lastName: String
    let creationDate: String
    let lastLogInDate: String
    let lastLogInLocation: String
    let lastPasswordChange: String
    
    static func defaultMetadata() -> UserMetadata {
        return UserMetadata(userId: "NaN",
                            email: "NaN",
                            firstName: "NaN",
                            lastName: "NaN",
                            creationDate: "NaN",
                            lastLogInDate: "NaN",
                            lastLogInLocation: "NaN",
                            lastPasswordChange: "NaN")
    }
}

struct UpdateProfileResponse: Decodable {
    let updateInfo: UpdateProfileInfo
}

struct UpdateProfileInfo: Decodable {
    let userId: String
}

// MARK: - Password Models

struct ChangePasswordResponse: Codable, Equatable {
    let passwordInfo: ChangePasswordInfo
}

struct ChangePasswordInfo: Codable, Equatable {
    let userId: String
}
