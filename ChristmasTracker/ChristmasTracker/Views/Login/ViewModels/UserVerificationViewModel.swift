//
//  UserVerificationViewModel.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 12/29/21.
//

import Foundation
import Combine

class UserVerificationViewModel: ObservableObject {
    @Published var isloading = false
    @Published var isErrorState = false
    
    @MainActor
    func generateOTP() async {
        // Send email address
        // Server generates OTP and verification key
        // Returns verification key and TTL
        
    }
    
    @MainActor
    func validateOTP() async {
        // Send email
    }
}

