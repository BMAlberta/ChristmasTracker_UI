//
//  ErrorResponseModels.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/8/26.
//

import Foundation

struct ErrorResponse: Codable, Sendable {
    let success: Bool
    let error: ErrorDetail
}

struct ErrorDetail: Codable, Sendable {
    let code: Int
    let errorCode: String
    let message: String
}
