//
//  GenericResponses.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 1/8/22.
//

import Foundation

struct NetworkResponse<T: Decodable>: Decodable {
    let error: ErrorResponse
    let payload: T
    
}
struct ErrorResponse: Decodable {
    let message: String?
}
