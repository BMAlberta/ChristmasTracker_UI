//
//  StoreEnvironmentKey.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 10/2/25.
//

import SwiftUI

@MainActor
struct StoreEnvironmentKey: @preconcurrency EnvironmentKey {
    static let defaultValue: Store<AppState> = StoreFactory.createProductionStore()
}

extension EnvironmentValues {
    var store: Store<AppState> {
        get { self[StoreEnvironmentKey.self] }
        set { self[StoreEnvironmentKey.self] = newValue }
    }
}
