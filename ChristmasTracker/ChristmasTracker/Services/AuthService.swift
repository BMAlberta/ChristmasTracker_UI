//
//  AuthService.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 1/17/21.
//

import Foundation
import Combine

enum AuthServiceError: Error {
    case networkError
    case unknown
    case invalidURL
    case decoder(error: Error)
    case url(error: URLError)
}

struct AuthService {
    
    func performLogin(_ credentials: Credentials) -> AnyPublisher<LoginResponse, AuthServiceError> {
        
//        let urlString = "http://webdev01.ad.bmalberta.com:3000/xmasList/auth/login"
        let urlString = "http://127.0.0.1:3000/tracker/auth/login"
        let params: [String: String] = ["email": credentials.username,
                                        "password": credentials.password]
        
        guard let url = URL(string : urlString) else {
            return Fail(error: AuthServiceError.invalidURL)
                .eraseToAnyPublisher()
        }
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        request.httpMethod = "POST"
        let json: [AnyHashable: AnyHashable] = params
        let jsonData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
        request.httpBody = jsonData
        
        return URLSession.shared
            .dataTaskPublisher(for: request)
            .mapError { AuthServiceError.url(error: $0) }
            .map { $0.data }
            .decode(type: NetworkResponse<LoginResponse>.self, decoder: JSONDecoder())
            .mapError { AuthServiceError.decoder(error: $0) }
            .map { $0.payload }
            .eraseToAnyPublisher()
    }
}
