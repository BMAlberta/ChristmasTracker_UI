//
//  UserState.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 10/1/25.
//

import Foundation

struct UserState: Codable, Equatable {
    var currentUser: String? // TODO: Change type
    var isloading: Bool = false
    var error: String? // TODO: Change type
    var isLoggedIn: Bool = false
    var authToken: String?
    var lastLoginDate: Date?
    
    static let initialState = UserState(
        currentUser: nil,
        isloading: false,
        error: nil,
        isLoggedIn: false,
        authToken: nil,
        lastLoginDate: nil
    )
    
    var userName: String {
//        currentUser?.name ?? "Guest"
        "Guest"
    }
    
    var userEmail: String {
//        currentUser?.email ?? ""
        ""
    }
}
