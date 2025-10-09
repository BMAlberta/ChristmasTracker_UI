//
//  SlimUserModel.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 1/8/22.
//

import Foundation

struct SlimUserModel: Codable {
    /// User's first name.
    let firstName: String
    
    /// Users's last name.
    let lastName: String
    
    /// User identifier.
    let rawId: String
    
    init(firstName: String = "", lastName: String = "", rawId: String = "") {
        self.firstName = firstName
        self.lastName = lastName
        self.rawId = rawId
    }
}
