//
//  EnrollServiceStore.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 11/21/22.
//

import Foundation



struct AccessKeyEnrollmentModel: Codable {
    let firstName: String
    let lastName: String
    let email: String
    let newPassword: String
    let confirmPassword: String
    let accessKey: String
}


enum AccessKeyEnrollmentError: String, Codable {
    case inputValidation = "100.5.1"
    case passwordValidation = "100.5.2"
    case emailRegistered = "100.5.3"
    case invalidAccessKey = "100.5.4"
    case userCreationFailed = "100.5.5"
    case unknown
    case none
    
    var errorMessage: String {
        switch self {
        case .inputValidation:
            return "The information you added contains one or more errors. Please check your entries and try again."
        case .passwordValidation:
            return "The password provided does not meet the complexity requirements."
        case .emailRegistered:
            return "The email address provided is already registered to another user."
        case .invalidAccessKey:
            return "The access key your provided is not valid or has expired."
        case .userCreationFailed, .unknown:
            return "We're temporarily unable to connect. Thank you for your patience. Please try again later."
        case .none:
            return ""
        }
    }
}

struct EnrollmentStateResponse {
    var success = false
    var error: AccessKeyEnrollmentError = .unknown
}

struct AccessKeyEnrollmentResponseModel: Codable {
    
}

enum EnrollServiceError: Error {
    case networkError
    case unknown
    case invalidURL
    case decoder(error: Error)
    case url(error: URLError)
    case inputError(error: AccessKeyEnrollmentError)
}

actor EnrollServiceStore {
    static func enrollWithAccessKey(_ model: AccessKeyEnrollmentModel) async throws -> EnrollmentStateResponse {
        let urlString = Configuration.getUrl(forKey: .lwEnroll)

        
        guard let url = URL(string: urlString) else {
            throw EnrollServiceError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        request.httpMethod = "POST"
        let json = try JSONEncoder().encode(model)
        request.httpBody = json
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw EnrollServiceError.networkError
            }
            
            if httpResponse.statusCode == 200 {
                LogUtility.logNetworkDetails(message: "EnrollService.enrollWithAccessKey",
                                             rawData: data)
                return EnrollmentStateResponse(success: true, error: .none)
            }
            
            if httpResponse.statusCode == 500 {
                LogUtility.logNetworkDetails(message: "EnrollService.enrollWithAccessKey",
                                             rawData: data)
                
                let decoder = JSONDecoder()
                let rawData = try decoder.decode(NetworkResponse<AccessKeyEnrollmentResponseModel>.self, from: data)
                guard let errorCode = rawData.error.message else {
                    throw EnrollServiceError.unknown
                }
                
                let error = AccessKeyEnrollmentError(rawValue: errorCode) ?? .unknown
                return EnrollmentStateResponse(success: false, error: error)
                
            }
            
            LogUtility.logNetworkDetails(message: "EnrollService.enrollWithAccessKey",
                                         rawData: data)
            return EnrollmentStateResponse(success: true, error: .none)
            
        } catch {
            LogUtility.logServiceError(message: "EnrollService.enrollWithAccessKey",
                                       error: EnrollServiceError.decoder(error: error))
            throw EnrollServiceError.decoder(error: error)
        }
    }
}
