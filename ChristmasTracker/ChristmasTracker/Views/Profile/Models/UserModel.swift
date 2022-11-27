//
//  UserModel.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 1/8/22.
//

import Foundation

struct UserModel: Codable {
    let _id: String
    let lastLogInLocation: String
    let email: String
    let firstName: String
    let lastName: String
    let creationDate: String //Date
    let lastLogInDate: String
    let lastPasswordChange: String
    
    init() {
        _id = ""
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
