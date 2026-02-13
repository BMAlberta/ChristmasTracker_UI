//
//  User.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/8/26.
//

import Foundation
struct User: Codable, Identifiable, Sendable {
    let id: String
    let email: String?
    let name: String
    let role: UserRole
    let createdAt: Date
    let updatedAt: Date
    enum CodingKeys: String, CodingKey {
        case id, email, name, role
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
enum UserRole: String, Codable, Sendable {
    case user = "USER"
    case admin = "ADMIN"
}
