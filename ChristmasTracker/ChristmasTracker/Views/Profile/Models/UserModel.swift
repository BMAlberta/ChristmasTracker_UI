//
//  UserModel.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 1/8/22.
//

import Foundation

struct UserModel: Codable {
    
    /// User identifier.
    let userId: String
    
    /// IP Address of the last login.
    let lastLogInLocation: String
    
    /// Registered email address.
    let email: String
    
    /// Users's first name.
    let firstName: String
    
    /// User's last name.
    let lastName: String
    
    /// Date the profile was created.
    let creationDate: String //Date
    
    /// Date of last login.
    let lastLogInDate: String
    
    /// Date of the last password change.
    let lastPasswordChange: String
    
    init() {
        userId = ""
        lastLogInLocation = ""
        email = ""
        firstName = ""
        lastName = ""
        creationDate = ""
        lastLogInDate = ""
        lastPasswordChange = ""
    }
}

struct AllUsersResponse: Decodable {
    let users: [UserModel]
}

struct CurrentUserResponse: Decodable {
    let user: UserModel
}
