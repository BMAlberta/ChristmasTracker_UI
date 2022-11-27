//
//  Models.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 1/15/21.
//

import Foundation
import SwiftUI
import Combine
import os

struct UserRegistrationResponse: Decodable {
    let otpRequired: Bool
}

struct OTPGenerationResponse: Decodable {
    let verificationKey: String
    let timeToLive: Int
}

struct OTPValidationResponse: Decodable {
    let otpValid: Bool
}
