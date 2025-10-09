//
//  Teaser.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 10/4/25.
//

import Foundation

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
