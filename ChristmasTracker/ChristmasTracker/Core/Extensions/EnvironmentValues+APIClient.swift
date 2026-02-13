//
//  EnvironmentValues+APIClient.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/13/26.
//

import SwiftUI

private struct APIClientKey: EnvironmentKey {
    static let defaultValue: APIClient = MockAPIClient()
}

extension EnvironmentValues {
    var apiClient: APIClient {
        get { self[APIClientKey.self] }
        set { self[APIClientKey.self] = newValue }
    }
}
