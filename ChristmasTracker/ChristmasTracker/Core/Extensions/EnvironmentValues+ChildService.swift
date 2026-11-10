//
//  EnvironmentValues+ChildService.swift
//  ChristmasTracker
//
//  The environment default is built from the inert repository: a view that reads the service
//  without the app injecting one gets a failed load, never fake data.
//

import SwiftUI

private struct ChildServiceKey: EnvironmentKey {
    static let defaultValue: ChildService = ChildService(repository: InertChildRepository())
}

extension EnvironmentValues {
    var childService: ChildService {
        get { self[ChildServiceKey.self] }
        set { self[ChildServiceKey.self] = newValue }
    }
}
