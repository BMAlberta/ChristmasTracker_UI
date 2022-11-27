//
//  SlimUserModel.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 1/8/22.
//

import Foundation

struct SlimUserModel: Decodable {
    let firstName: String
    let lastName: String
    let rawId: String
    
    init(firstName: String = "", lastName: String = "", rawId: String = "") {
        self.firstName = firstName
        self.lastName = lastName
        self.rawId = rawId
    }
}
