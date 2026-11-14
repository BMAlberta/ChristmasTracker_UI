//
//  EnvironmentValues+StatsService.swift
//  ChristmasTracker
//
//  The environment default is built from the inert loader: a view that reads the service without
//  the app injecting one gets a failed load, never fake data.
//

import SwiftUI

private struct StatsServiceKey: EnvironmentKey {
    static let defaultValue: StatsService = StatsService(repository: InertStatsLoader())
}

extension EnvironmentValues {
    var statsService: StatsService {
        get { self[StatsServiceKey.self] }
        set { self[StatsServiceKey.self] = newValue }
    }
}
