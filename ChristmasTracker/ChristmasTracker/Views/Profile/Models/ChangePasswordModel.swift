//
//  ChangePasswordModel.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 1/8/22.
//

import Foundation

struct ChangePasswordModel: Codable {
    var oldPassword: String = ""
    var newPassword: String = ""
    var newPasswordConfirmation: String = ""
}

struct PasswordResetResponse: Decodable {
    let userId: String
}
