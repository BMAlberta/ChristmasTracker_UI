//
//  UserAPIService.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 10/1/25.
//

import Foundation


protocol UserDataManaging {
    func authenticateUser(_ credentials: Credentials) async throws -> LoginResponse
    func performLogout() async
    
    func resetPassword(model: ChangePasswordModel) async throws -> PasswordResetResponse
 
    func enrollWithAccessKey(_ model: AccessKeyEnrollmentModel) async throws -> EnrollmentStateResponse
    
    func getUserDetails(forId userId: String) async throws -> CurrentUserResponse
}


actor UserAPIService: UserDataManaging {
    func authenticateUser(_ credentials: Credentials) async throws -> LoginResponse {
        return LoginResponse(userInfo: "foo")
    }
    
    func performLogout() async {
        return
    }
    
    func resetPassword(model: ChangePasswordModel) async throws -> PasswordResetResponse {
        return PasswordResetResponse(userId: "foo")
    }
    
    func enrollWithAccessKey(_ model: AccessKeyEnrollmentModel) async throws -> EnrollmentStateResponse {
        return EnrollmentStateResponse()
    }
    
    func getUserDetails(forId userId: String) async throws -> CurrentUserResponse {
        return CurrentUserResponse(user: UserModel())
    }
    
    
}
