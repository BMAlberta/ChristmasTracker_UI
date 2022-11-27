//
//  UserRegistrationViewModel.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 12/29/21.
//

import Foundation
import Combine

class UserRegistrationViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var isErrorState = false
    
    private var _session: SessionManaging
    
    init(_ session: SessionManaging) {
        _session = session
    }
    
    
    @MainActor
    func register() async {
        // Send email/password
        // Server to determine if email is registered
        // Server to validate password meets requirements
        // Server returns registration response
    }
}

