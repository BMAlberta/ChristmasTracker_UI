//
//  UserServiceStore.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 12/23/21.
//

import Foundation
import Combine

enum UserServiceError: Error {
    case networkError
    case unknown
    case userNotFound
    case decoder(error: Error)
    case url(error: URLError)
}

actor UserServiceStore {
    
    static func getCurrentUserDetails(token: String) async throws -> CurrentUserResponse {
        let urlString = Configuration.getUrl(forKey: .userDetails)
        
        guard let url = URL(string: urlString) else {
            throw UserServiceError.networkError
        }
        
        let request = NetworkUtility.createBaseRequest(url: url,
                                                       method: .get,
                                                       token: token)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw UserServiceError.networkError
            }
            LogUtility.logNetworkDetails(message: "UserService.getCurrentUserDetails",
                                         rawData: data)
            let decoder = JSONDecoder()
            let rawData = try decoder.decode(NetworkResponse<CurrentUserResponse>.self, from: data)
            return rawData.payload
        } catch {
            LogUtility.logServiceError(message: "UserService.getCurrentUserDetails",
                                       error: UserServiceError.decoder(error: error))
            throw UserServiceError.decoder(error: error)
        }
    }
}
