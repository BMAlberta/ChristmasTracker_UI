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
    
    static func getUserDetails(forId userId: String) async throws -> CurrentUserResponse {
        let baseUrlString = Configuration.getUrl(forKey: .userDetails)
        let finalUrlString = baseUrlString + userId
       
        guard let url = URL(string: finalUrlString) else {
            throw UserServiceError.networkError
        }
        
        let request = NetworkUtility.createBaseRequest(url: url,
                                                       method: .get)
        
        do {
            let (data, response) = try await ServiceCache.shared.fetchNetworkResponse(request: request)
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
