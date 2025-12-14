//
//  UserAPIService.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 10/1/25.
//

import Foundation




protocol UserDataProviding {
    func authenticateUser(_ credentials: Credentials) async throws -> AuthResponse
    func performLogout() async throws
    
    func enrollWithAccessKey(_ model: AccessKeyEnrollmentModel) async throws
    
    func updateProfileName(userId: String, firstName: String, lastName: String) async throws -> UpdateProfileResponse
    
    func fetchUserMetadata() async throws -> UserMetadataResponse
    
    func updatePassword(oldPassword: String, newPassword: String) async throws -> ChangePasswordResponse
    
    func checkSession() async throws
}


actor UserAPIService: UserDataProviding {
    
    private let seesion = URLSession.shared
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    
    func authenticateUser(_ credentials: Credentials) async throws -> AuthResponse {
        
        let urlString = Configuration.getUrl(forKey: .auth)
        let params: [String: String] = ["email": credentials.username,
                                        "password": credentials.password]
        
        guard let url = URL(string: urlString) else {
            throw APIError.invalidRequest
        }
        
        var request = NetworkUtility.createBaseRequest(url: url, method: .post)

        let json: [AnyHashable: AnyHashable] = params
        let jsonData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
        request.httpBody = jsonData
        
        let (data, response) = try await seesion.data(for: request)
        
        try APIService.validateResponse(response)
        
        let authResponse = try decoder.decode(NetworkResponse<AuthResponse>.self, from: data)
        
        return authResponse.payload
        
    }
    
    func performLogout() async throws {
        let urlString = Configuration.getUrl(forKey: .logout)
        
        guard let url = URL(string: urlString) else {
            throw APIError.invalidRequest
        }
        
        var request = NetworkUtility.createBaseRequest(url: url, method: .post)
        let (data, response) = try await seesion.data(for: request)
        
        return
    }
    
    func enrollWithAccessKey(_ model: AccessKeyEnrollmentModel) async throws {
        return
    }
    
    func updateProfileName(userId: String, firstName: String, lastName: String) async throws -> UpdateProfileResponse {
        let urlString = Configuration.getUrl(forKey: .userDetails)
        let params: [String: String] = ["userId": userId,
                                        "firsName": firstName,
                                        "lastName": lastName]
        
        guard let url = URL(string: urlString) else {
            throw APIError.invalidRequest
        }
        
        var request = NetworkUtility.createBaseRequest(url: url, method: .patch)

        let json: [AnyHashable: AnyHashable] = params
        let jsonData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
        request.httpBody = jsonData
        
        let (data, response) = try await seesion.data(for: request)
        
        try APIService.validateResponse(response)
        
        let updateResponse = try decoder.decode(NetworkResponse<UpdateProfileResponse>.self, from: data)
        
        return updateResponse.payload
    }
    
    func fetchUserMetadata() async throws -> UserMetadataResponse {
        let urlString = Configuration.getUrl(forKey: .userMetadata)
        
        guard let url = URL(string: urlString) else {
            throw APIError.invalidRequest
        }
        
        let request = NetworkUtility.createBaseRequest(url: url, method: .get)

        let (data, response) = try await seesion.data(for: request)
        
        try APIService.validateResponse(response)
        
        let updateResponse = try decoder.decode(NetworkResponse<UserMetadataResponse>.self, from: data)
        
        return updateResponse.payload
    }
    
    func updatePassword(oldPassword: String, newPassword: String) async throws -> ChangePasswordResponse {
        let urlString = Configuration.getUrl(forKey: .resetPassword)
        let params: [String: String] = ["oldPassword": oldPassword,
                                        "newPassword": newPassword]
        
        guard let url = URL(string: urlString) else {
            throw APIError.invalidRequest
        }
        
        var request = NetworkUtility.createBaseRequest(url: url, method: .post)

        let json: [AnyHashable: AnyHashable] = params
        let jsonData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
        request.httpBody = jsonData
        
        let (data, response) = try await seesion.data(for: request)
        
        try APIService.validateResponse(response)
        print(String(data: data, encoding: .utf8))
        let changePasswordResponse = try decoder.decode(NetworkResponse<ChangePasswordResponse>.self, from: data)
        
        return changePasswordResponse.payload
    }
    
    func checkSession() async throws {
        let urlString = Configuration.getUrl(forKey: .ping)
        
        guard let url = URL(string: urlString) else {
            throw APIError.invalidRequest
        }
        
        var request = NetworkUtility.createBaseRequest(url: url, method: .get)
        
        let (data, response) = try await seesion.data(for: request)

        try APIService.validateResponse(response)

        return
    }
}
