//
//  AuthServiceError.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 1/17/21.
//

import Foundation
import Combine

/// Authentication Errors
enum AuthServiceError: Error {
    case networkError
    case unknown
    case invalidURL
    case decoder(error: Error)
    case url(error: URLError)
}

actor AuthServiceStore {
    static func performLogin(_ credentials: Credentials) async throws -> LoginResponse {
        let urlString = Configuration.getUrl(forKey: .auth)
        let params: [String: String] = ["email": credentials.username,
                                        "password": credentials.password]
        
        guard let url = URL(string: urlString) else {
            throw AuthServiceError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let appVersion = Configuration.appVersion
        request.setValue(appVersion, forHTTPHeaderField: "av")
        
        request.httpMethod = "POST"
        let json: [AnyHashable: AnyHashable] = params
        let jsonData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
        request.httpBody = jsonData
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 400 || httpResponse.statusCode == 200 else {
                throw AuthServiceError.networkError
            }
            
            LogUtility.logNetworkDetails(message: "AuthService.performLogin",
                                         rawData: data)
            
            let decoder = JSONDecoder()
            let rawData = try decoder.decode(NetworkResponse<LoginResponse>.self, from: data)
            ServiceCache.shared.clearCache()
            return rawData.payload
            
        } catch {
            LogUtility.logServiceError(message: "AuthService.performLogin",
                                       error: AuthServiceError.decoder(error: error))
            throw AuthServiceError.decoder(error: error)
        }
    }
    
    static func performLogout() async -> () {
        let urlString = Configuration.getUrl(forKey: .logout)
        
        guard let url = URL(string: urlString) else {
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        request.httpMethod = "POST"
        
        do {
            let _ = try await URLSession.shared.data(for: request)
            ServiceCache.shared.clearCache()
            return
            
        } catch {
            ServiceCache.shared.clearCache()
            return
        }
    }
    
    static func resetPassword(model: ChangePasswordModel) async throws -> PasswordResetResponse {
        let urlString = Configuration.getUrl(forKey: .resetPassword)
        
        guard let url = URL(string: urlString) else {
            throw AuthServiceError.invalidURL
        }
        
        var request = NetworkUtility.createBaseRequest(url: url,
                                                       method: .post)
        
        let params: [String: String] = ["oldPassword": model.oldPassword,
                                        "newPassword": model.newPassword]
        let json: [AnyHashable: AnyHashable] = params
        let jsonData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
        request.httpBody = jsonData
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 400 || httpResponse.statusCode == 200 else {
                throw AuthServiceError.networkError
            }
            LogUtility.logNetworkDetails(message: "AuthService.resetPassword",
                                         rawData: data)
            let decoder = JSONDecoder()
            let rawData = try decoder.decode(NetworkResponse<PasswordResetResponse>.self, from: data)
            return rawData.payload
            
        } catch  {
            LogUtility.logServiceError(message: "AuthService.resetPassword",
                                       error: AuthServiceError.decoder(error: error))
            throw AuthServiceError.decoder(error: error)
        }
    }
}
