//
//  UIModels.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 11/15/25.
//

import Foundation

// MARK: - Teaser Models
struct Teaser: Equatable, Codable {
    let type: TeaserType
    let name: String
    let message: String
}

enum TeaserType: String, Codable {
    case greeting
    case timeInfo
    case timeWarning
    case timeCritical
}

// MARK: - Toast Models
struct UpdateInfoModel: Decodable {
    let availableVersion: String
    let downloadUri: String
}

struct Toast: Codable {
    let heading: String
    let body: String
    let icon: String
    let action: ToastAction
}

enum ToastAction: Codable {
    case dismiss
}

// MARK: - Update Models

struct UpdateInfoModelResponse: Decodable {
    let version: UpdateInfoModel
}





