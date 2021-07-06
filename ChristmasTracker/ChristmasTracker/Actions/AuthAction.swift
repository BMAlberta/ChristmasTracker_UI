//
//  LoginAction.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 1/17/21.
//

import Foundation

enum AuthAction {
    case doLogin(credentials: Credentials)
    case loginComplete(res: LoginResponse)
    case loginError(error: AuthMiddlewareError?)
}
