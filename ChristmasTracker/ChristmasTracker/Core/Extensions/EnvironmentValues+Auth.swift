//
//  EnvironmentValues+Auth.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/11/26.
//

import SwiftUI
// MARK: - Environment Key
private struct AuthenticationServiceKey: EnvironmentKey {
    static let defaultValue: AuthenticationService = {
        let repository = MockAuthenticationRepository()
        let sessionManager = SessionManager(authRepository: repository)
        return AuthenticationService(
            repository: repository,
            sessionManager: sessionManager
        )
    }()
}
extension EnvironmentValues {
    var authenticationService: AuthenticationService {
        get { self[AuthenticationServiceKey.self] }
        set { self[AuthenticationServiceKey.self] = newValue }
    }
}
