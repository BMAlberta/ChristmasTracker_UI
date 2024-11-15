//
//  ChangePasswordModel.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 1/8/22.
//

import Foundation

struct ChangePasswordModel: Codable {
    
    /// Uesrs's old password.
    var oldPassword: String = ""
    
    /// Users's new password.
    var newPassword: String = ""
    
    /// User's new password.
    var newPasswordConfirmation: String = ""
}

struct PasswordResetResponse: Decodable {
    let userId: String
}
