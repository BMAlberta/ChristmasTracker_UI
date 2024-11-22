//
//  UpdateServiceStore.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 12/24/21.
//

import Foundation
import Combine

enum UpdateServiceError: Error {
    case networkError
    case unknown
    case decoder(error: Error)
    case url(error: URLError)
    case invalidURL
}

actor UpdateServiceStore {
    static func fetchUpdateInfo() async throws -> UpdateInfoModelResponse {
        let urlString = Configuration.configUrl
        
        guard let url = URL(string: urlString) else {
            throw UpdateServiceError.invalidURL
        }
        
        var request = NetworkUtility.createBaseRequest(url: url, method: .get)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 400 || httpResponse.statusCode == 200 else {
                throw UpdateServiceError.networkError
            }
            LogUtility.logNetworkDetails(message: "UpdateService.fetchUpdateInfo",
                                         rawData: data)
            let decoder = JSONDecoder()
            let rawData = try decoder.decode(UpdateInfoModelResponse.self, from: data)
            return rawData
        } catch {
            let thrownError = UpdateServiceError.decoder(error: error)
            LogUtility.logServiceError(message: "UpdateService.fetchUpdateInfo",
                                       error: thrownError)
            throw thrownError
        }
    }
}
