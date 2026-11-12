//
//  ItemStatus.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/14/26.
//
import SwiftUI
import Foundation

// MARK: ItemStatus

enum ItemStatus: String, Codable, Sendable, Hashable {
    case available = "AVAILABLE"
    case partial = "PARTIAL"
    case purchased = "PURCHASED"
    case wrapped = "WRAPPED"
    case gifted = "GIFTED"

    var displayName: String {
        switch self {
        case .available: return "Available"
        case .partial: return "Partially Purchased"
        case .purchased: return "Purchased"
        case .wrapped: return "Wrapped"
        case .gifted: return "Gifted"
        }
    }

    var icon: String {
        switch self {
        case .available: return "circle"
        case .partial: return "circle.lefthalf.filled"
        case .purchased: return "checkmark.circle.fill"
        case .wrapped: return "gift.fill"
        case .gifted: return "hand.thumbsup.fill"
        }
    }

    @MainActor var color: Color {
        switch self {
        case .available: return .gray
        case .partial: return .orange
        case .purchased: return .green
        case .wrapped: return .blue
        case .gifted: return .purple
        }
    }

}
