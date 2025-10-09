//
//  UserAPIService.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 10/1/25.
//

import Foundation

enum APIError: Error {
    case invalidResponse
    case unauthorized
    case decoder(error: Error)
    case url(error: Error)
    case generic(Int)
    case invalidRequest
    case badRequest
    case serverError
    case notFound
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response received"
        case . unauthorized:
            return "Authentication required"
        case .decoder(error: let error):
            return "Error while decoding: \(error)"
        case .url(error: let error):
            return "Error while building URL: \(error)"
        case .generic(let code):
            return "General error with code: \(code)"
        case .invalidRequest:
            return "Invalid request"
        case .badRequest:
            return "Bad URL request"
        case .serverError:
            return "Internal server error"
        case .notFound:
            return "Endpoint not found"
        }
    }
}


protocol UserDataProviding {
    func authenticateUser(_ credentials: Credentials) async throws -> LoginResponse
    func performLogout() async
    
    func resetPassword(model: ChangePasswordModel) async throws -> PasswordResetResponse
 
    func enrollWithAccessKey(_ model: AccessKeyEnrollmentModel) async throws -> EnrollmentStateResponse
    
    func getUserDetails(forId userId: String) async throws -> CurrentUserResponse
}


actor UserAPIService: UserDataProviding {
    
    
    private let seesion = URLSession.shared
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    
    func authenticateUser(_ credentials: Credentials) async throws -> LoginResponse {
        
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
        
        let authResponse = try decoder.decode(NetworkResponse<LoginResponse>.self, from: data)
        
        return authResponse.payload
        
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
