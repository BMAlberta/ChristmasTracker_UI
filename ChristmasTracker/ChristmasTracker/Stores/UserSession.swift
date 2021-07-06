//
//  UserSession.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 1/15/21.
//

import Foundation
import Combine
import SwiftUI

enum SessionState {
    case noAuth
    case loggedIn
    case failedAuth
}

class UserSession {
    var state: SessionState = .noAuth
    
    var authToken: String = ""
    var userId: String = ""
    
    func login() {
        state = .loggedIn
        
    }
    
    func logout() {
        authToken = ""
        userId = ""
        state = .noAuth
    }
    
    func storeUserData(token: String, userId: String) {
        self.authToken = token
        self.userId = "5fecfccb5a142be878648c8c"
        state = .loggedIn
        //        startSessionTimer()
    }
    
    
    
    func performLogin(_ credentials: Credentials) -> AnyPublisher<LoginResponse, ListError> {
        
        
        let urlString = "http://webdev01.ad.bmalberta.com:3000/xmasList/auth/login"
        let params: [String: String] = ["email": credentials.username,
                                        "password": credentials.password]
        
        guard let url = URL(string : urlString) else {
            return Fail(error: ListError.invalidURL)
                .eraseToAnyPublisher()
        }
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if (!self.authToken.isEmpty) {
            request.setValue(self.authToken, forHTTPHeaderField: "auth-token")
        }
        request.httpMethod = "POST"
        let json: [AnyHashable: AnyHashable] = params
        let jsonData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
        request.httpBody = jsonData
        
        return URLSession.shared
            .dataTaskPublisher(for: request)
            .mapError { ListError.url(error: $0) }
            .map { $0.data }
            .decode(type: NetworkResponse<LoginResponse>.self, decoder: JSONDecoder())
            .mapError { ListError.decoder(error: $0) }
            .map { $0.payload }
            .eraseToAnyPublisher()
        
    }
}
